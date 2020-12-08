#!/usr/bin/perl -s
#doniarto@numisec.com
#history : Feb 12,2019 initial

use POSIX qw(strftime);
use File::Basename;
use File::Copy qw(copy move);
use vars qw($r,$c);
use Cwd qw(abs_path);
#use Data::Dumper;

#PARAMETERS
my @PATH_BIN = qw(/bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin);
my $maindir = abs_path();
my $backupdir = "/etc/nmc_backup";
my $control_file = "harden_ctl.conf";

if ((!$e)) {
  print "Usage: $swn <option>\n";
  print "Option:\n";
  print "  -c=<control_file>         specify custom control file name\n";
  print "  -e                        run hardening\n";
  print "  -r=<empty|*|yyyymmddhhmi> rollback hardening\n";
  print "     empty flag             to last previous backup\n";
  print "     * flag                 to 1st previous backup\n";
  print "     yyyymmddhhmi flag      to 1st certain previous backup\n";
  exit 1
}

#recommended banner message
#my @banner_msg = ("Authorized uses only. All activity may be monitored and reported.\n");
my %banner_msg = ("/etc/motd" => "Authorized uses only. All activity may be monitored and reported.\n",
                  "/etc/issue" => "Authorized uses only. All activity may be monitored and reported.\n",
                  "/etc/issue.net" => "Authorized uses only. All activity may be monitored and reported.\n");

#recommended PAM
my %pam_cfg = ("/etc/security/pwquality.conf" => {"minlen"  => " = 8",
                                                  "dcredit" => " = -1",#provide at least one digit
                                                  "ucredit" => " = -1",#provide at least one uppercase character
                                                  "ocredit" => " = -1",#provide at least one special character
                                                  "lcredit" => " = -1"},#provide at least one lowercase character
              "/etc/pam.d/password-auth" => {"password    requisite     pam_pwquality.so" => " try_first_pass remember=3"},
              "/etc/pam.d/system-auth" => {"password    requisite     pam_pwquality.so" => " try_first_pass remember=3"}
              );

#recommended shadow
my %user_cfg = ("PASS_MAX_DAYS" => "   90",
                "PASS_MIN_DAYS" => "   7",
                "PASS_WARN_AGE" => "   7");

#recommended sshd parameters
my %sshd_parameters = ("Protocol " => "2",
                       "LogLevel " => "INFO",
                       "X11Forwarding " => "no",
                       "MaxAuthTries " => "4",
                       "IgnoreRhosts " => "yes",
                       "HostbasedAuthentication " => "no",
                       #"PermitRootLogin " => "no",
                       "PermitEmptyPasswords " => "no",
                       "PermitUserEnvironment " => "no",
                       #"MACs " => "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com",
                       "ClientAliveInterval " => "300",
                       "ClientAliveCountMax " => "0",
                       "LoginGraceTime " => "60",
                       "Banner " => "/etc/issue.net");

#HARDENING TASK

sub run_command {
  my $com = shift;
  my $rst = "";

  print "run_command:".$com."\n";
  open(CMD,"${com} 2>>err.txt|");
  while (my $text = <CMD>) {
    $rst .= qq{$text};
  }
  return $rst
}

sub get_time {
  $t = time;
  $s = sprintf "%06.3f",$t-int($t/60)*60;
  $s =~ s/\d+\.//;
  $tsp = strftime("%Y%m%d %H:%M:%S.$s", localtime $t);
  $fsp = strftime("%Y%m%d%H%M", localtime $t);
  $msp = strftime("%a, %d %b %G %H:%M:%S %Z", localtime $t);
}

sub get_binary_location {
  my $com = shift;
  my $rst = "";

  foreach $path (@PATH_BIN) {
    if ( -e $path."/".$com ) {
        $rst = $path."/".$com;
        last;
    }
  }
  return $rst;
}

sub create_dir {
  my $dir = shift;

  if ( ! -e $dir ) {
    mkdir $dir or die "Creating ".$dir." $!\n";
  }
}

sub read_file {
  my $file = shift;

  print "reading:".$file."\n";
  if ( -e $file ) {
    open(IN, "< $file") or print "Opening ".$file." $!\n";
    @rst = <IN>;
    close(IN);
    return @rst
  } else {
    print "file ".$file." not exist\n";
    return ();
  }
}

sub write_file {
  my $file = shift;
  my $ref = shift;
  my @data = @{$ref};
  my $appd = shift;

  if ($appd) {
    if ( -e $file ) {
      print "appending:".$file."\n";
      open(OUT, ">> $file") or die "Writing ".$file." $!\n";
      print OUT @data;
      close(OUT);
    } else {
      print "file ".$file." not exist\n";
    }
  } else {
    print "writing:".$file."\n";
    open(OUT, "> $file") or die "Writing ".$file." $!\n";
    print OUT @data;
    close(OUT);
  }
}

sub remove_key_data {
  my $ref = shift;
  my @data = @{$ref};
  my $key = shift;
  
  @new_content=();
  foreach (@data) {
    if ($_ =~ /${key}/) {
      $_ = ""
    };
    push @new_content, $_;
  }
  return @new_content;
}

sub change_key_data {
  my $ref = shift;
  my @data = @{$ref};
  my $key = shift;
  my $value = shift;
  
  if ($key eq "") {
    @new_content = (); 
  } else {
    @new_content = remove_key_data(\@data,$key);
  }
  push @new_content, $key.$value;
  return @new_content;
}

sub backup_file {
  my $full_path_file = shift;

  create_dir($backupdir);
  $file = basename($full_path_file);
  $new_file_name = $file.".".$fsp;
  print "backup copy ".$full_path_file.",".$backupdir."/".$new_file_name."\n";
  copy $full_path_file, $backupdir."/".$new_file_name;
}

sub restore_file {
  my $full_path_file = shift;
  my $last = shift;

  if ($last != 1) {
    $file = basename($full_path_file).".".$last;
  } else {
    $file = basename($full_path_file);
  }
  opendir(DIR, "$backupdir") or die "Openning: ".$dir." $!";
  print "finding ".$file." file\n";
  my @files = sort { $a cmp $b } (grep { $_ =~ /${file}/ } readdir(DIR));
  closedir(DIR);
  print Dumper @files;
  $num = scalar(@files);
  if ($num == 0) {
    die "no backup found for $file\n";
  } else { 
    $first_file = $backupdir."/".$files[0];
    $last_file = $backupdir."/".$files[$num - 1];
    if ($last == 1) {
      print "restore last copy ".$last_file.",".$full_path_file."\n";
      copy $last_file, $full_path_file
    } else {
      #restore 1st backup file
      print "restore 1st copy ".$first_file.",".$full_path_file."\n";
      copy $first_file, $full_path_file
    }
  }
}

#HARDENING FUNCTION

sub add_banner {
  return if (!keys %banner_msg);
  print "---Add Banner---\n";

  if ($r) {
    for $target ( keys %banner_msg ) {
      restore_file($target,$r);
    }
  } else {
    for $target ( keys %banner_msg ) {
      backup_file($target);
      @new_content = $banner_msg{$target};
      write_file($target,\@new_content);
    }
  }
}

sub pam_configuration {
  return if (!keys %pam_cfg);
  print "---PAM Configuration---\n";
  
  if ($r) {
    for $target ( keys %pam_cfg ) {
      restore_file($target,$r);
    }
  } else {
    for $target ( keys %pam_cfg ) {
      backup_file($target);
      @new_content = read_file($target);
      for $pam ( keys %{$pam_cfg{$target}} ) {
        $pam_val = $pam_cfg{$target}{$pam};
        @new_content = change_key_data(\@new_content,$pam,$pam_val."\n");
      }
      #print @new_content;
      write_file($target,\@new_content);
    }
  }
  
}

sub shadow_configuration {
  return if (!keys %user_cfg);
  print "---Shadow Configuration---\n";
  #5.4.1 Set Shadow Password Suite Parameters
  my $target = "/etc/login.defs";
  
  if ($r) {
    restore_file($target,$r);
  } else {
    backup_file($target);
    @new_content = read_file($target);
    for $usr ( keys %user_cfg ) {
      $usr_val = $user_cfg{$usr};
      @new_content = change_key_data(\@new_content,$usr,$usr_val."\n");
    }
    #print @new_content;
    write_file($target,\@new_content);
  }
}

sub ssh_configuration {
  return if (!keys %sshd_parameters);
  print "---SSH Configuration---\n";
  #5.2 SSH Server Configuration
  my $target = "/etc/ssh/sshd_config";

  if ($r) {
    restore_file($target,$r);
    if ( $OS_NAME eq "SunOS" ) {
      run_command($BIN_PKGCHK." -f -n -p ${target}");
      run_command($BIN_SVCADM." restart svc:/network/ssh");
    } else {
      if ( $OS_RELEASE eq "el7" ) {
        run_command($BIN_SYSTEMCTL." reload sshd");
      } else {
        run_command($BIN_SERVICE." sshd reload");
      };
    };
  } else {
    backup_file($target);
    my @new_content = read_file($target);
    #create config / scan current status
    for $par ( keys %sshd_parameters ) {
      $par_status = $sshd_parameters{$par};
      @new_content = change_key_data(\@new_content,$par," ".$par_status."\n");
    }
    #print @new_content;
    write_file($target,\@new_content);
    if ( $OS_NAME eq "SunOS" ) {
      run_command($BIN_PKGCHK." -f -n -p ${target}");
      run_command($BIN_SVCADM." restart svc:/network/ssh");
    } else {
      if ( $OS_RELEASE eq "el7" ) {
        run_command($BIN_SYSTEMCTL." reload sshd");
      } else {
        run_command($BIN_SERVICE." sshd reload");
      };
    };
    #print read_file($target);
  }
}

#MAIN

get_time();
#Initialization
$BIN_UNAME = get_binary_location("uname");
$BIN_HOSTNAME = get_binary_location("hostname");
$BIN_SYSTEMCTL = get_binary_location("systemctl");
$BIN_SYSCTL = get_binary_location("sysctl");
$BIN_CHMOD = get_binary_location("chmod");
$BIN_CHOWN = get_binary_location("chown");
$BIN_RPM = get_binary_location("rpm");
$BIN_YUM = get_binary_location("yum");
$BIN_MODPROBE = get_binary_location("modprobe");
$BIN_LSMOD = get_binary_location("lsmod");
$BIN_RMMOD = get_binary_location("rmmod");
$BIN_INSMOD = get_binary_location("insmod");
$BIN_SERVICE = get_binary_location("service");
$BIN_SVCADM = get_binary_location("svcadm");
$BIN_PKGCHK = get_binary_location("pkgchk");

$OS_NAME = run_command($BIN_UNAME." -s");
chomp($OS_NAME);
if ($OS_NAME eq "Linux") {
  $OS_RELEASE = run_command($BIN_UNAME." -r");
  $OS_RELEASE = ($OS_RELEASE =~ /.+\.(.+)\..+$/)? $1 : $OS_RELEASE;
} else {
  $OS_RELEASE = run_command($BIN_UNAME." -r");
}
print "OS_NAME: $OS_NAME, OS_RELEASE: $OS_RELEASE\n";

if ($c) {
  #clear recommended banner message
  %banner_msg = ();
  #clear recommended PAM
  %pam_cfg = ();
  #clear recommended shadow
  %user_cfg = ();
  #clear recommended sshd parameters
  %sshd_parameters = ();

  $control_file = $c if ($c != 1);
  unless (open(IN, "$control_file")) {
    die ("File $control_file $!")
  };
  print "Audit Points:\n";
  while ($line = <IN>) {
    chomp $line;
    # Trim leading and trailing blanks
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
  
    $raw = "";
    if ($line !~ /^\#/ && $line ne "") {
      #print "-->".$line."\n";
      if ($line =~ /^(.+?)\;(.+?)\;\{\{(.+)\}\}$/) {
        ($name, $cmnd, $param) = $line =~ /^(.+?)\;(.+?)\;\{\{(.+)\}\}$/;
        print $name.":".$cmnd.":".$param."\n";
        @params = split(/\;/, $param);
        foreach $x (@params) {
          eval $x;
        };
      } else {
        ($name, $cmnd, $param) = split(/\;/, $line);
        print $name.":".$cmnd.":".$param."\n";
        eval $param;
      }
    }
  }
}

print "Parameters :\n";
print "recommended banner message : ";
print join("-",%banner_msg)."\n";
print "recommended PAM : ";
print join("-",%pam_cfg)."\n";
print "recommended shadow : ";
print join("-",%user_cfg)."\n";
print "recommended sshd parameters : ";
print join("-",%sshd_parameters)."\n";

print "Execution :\n";
add_banner();
pam_configuration();
shadow_configuration();
ssh_configuration();

1;