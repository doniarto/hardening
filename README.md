hardening
=========

Lite script `harden_run.pl` ini digunakan untuk partial hardening point-point berikut:

RHEL6,RHEL7:
  - Add Banner
  - PAM Configuration
  - Shadow Configuration
  - SSH Configuration
  - beberapa konfigurasi seperti PAM Configuration

SOLARIS10:
  - Add Banner
  - SSH Configuration
  - beberapa konfigurasi seperti PAM Configuration

Bila file backup masih tersedia, script bisa melakukan rollback point-point yang telah dihardening sebelumnya.

Requirements
------------

Script ini telah dicoba pada environtment Perl 5 di RHEL6, RHEL7, dan SOLARIS10 tanpa installasi modul tambahan atau hanya menggunakan modul ad-hoc/bawaan Perl 5.
Membutuhkan priviledge Admin untuk menjalankannya.
Script akan membuat direktori `/etc/nmc_backup` untuk menyimpan file konfigurasi sebelum dilakukan perubahan, fungsi rollback membutuhkan file yang berada pada directory ini.

Script Variables
----------------

Script menggunakan control file dengan format seperti berikut:

```
#name;command_to_check;parameters
D.6.1.9. Ensure SSH Banner file is configured;grep "^Banner" /etc/ssh/sshd_config;$sshd_parameters{"Banner "}="/etc/issue"
```

Pada dasarnya di control menggunakan parameters yang sebenarnya adalah variabel hashes atau associative arrays Perl dari masing-masing fungsi hardening nya sebagai berikut:
 - Add Banner: 
   $banner_msg{"path_file_banner"}="text_isi_banner", contoh: $banner_msg{"/etc/issue"}="Wellcome".
   
 - PAM Configuration: 
   $pam_cfg{"path_config_file"}{"key"}=" value", contoh: $pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5".
   konsepnya:
   parameter "key" adalah suatu kata tertentu yang akan dicari dan di hapus didalam file "path_config_file"
   misalkan: sebelumnya parameter "key" = 'password    sufficient    pam_unix.so' didalam file  "/etc/pam.d/system-auth" adalah :

```
[root@centos7 ansible-scripts]# grep "password    sufficient    pam_unix.so" /etc/pam.d/system-auth
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
[root@centos7 ansible-scripts]#
```
   kemudian parameter "value" = '  sha512 remember=5', setelah script dijalankan baris yang mengandung parameter "key" akan dihapus, lalu diganti dengan baris baru paling bawah berisi parameter "key"+"value", sehingga menjadi sebagai berikut:

```
[root@centos7 ansible-scripts]# grep "password    sufficient    pam_unix.so" /etc/pam.d/system-auth
password    sufficient    pam_unix.so sha512 remember=5
[root@centos7 ansible-scripts]#
``` 

  - Shadow Configuration:
    $user_cfg{"key"}="value", contoh: $user_cfg{"PASS_MIN_LEN"}="   8".
    Konsep merubah file konfigurasinya sama seperti PAM Configuration, hanya saja cuma bisa digunakan untuk memodifikasi file `/etc/login.defs`
    
  - SSH Configuration:
    $sshd_parameters{"key"}="value", contoh: $sshd_parameters{MaxAuthTries}=5.
    Konsep merubah file konfigurasinya sama seperti PAM Configuration, hanya saja cuma bisa digunakan untuk memodifikasi file `/etc/ssh/sshd_config`
   
Dependencies
------------

N/A


Example Usage
-------------

Berikut option-option yang ada pada script ini :

```
[root@centos7 ansible-scripts]# ./harden_run.pl
Usage:  <option>
Option:
  -c=<control_file>         specify custom control file name
  -e                        run hardening
  -r=<empty|*|yyyymmddhhmi> rollback hardening
     empty flag             to last previous backup
     * flag                 to 1st previous backup
     yyyymmddhhmi flag      to 1st certain previous backup
[root@centos7 ansible-scripts]#
```

Menjalankan hardening (menggunakan Ansible):

```
doni@LAPTOP-OPP19HPH:~/Scripts/hardening$ ansible-playbook -i hosts hardening.yml -e @vars.yml -e 'hostname=solaris10 config_name=harden_ctl_sol.conf'

PLAY [remote tasks] *********************************************************************************************************************************************************************************************

TASK [Gathering Facts] ******************************************************************************************************************************************************************************************
[WARNING]: Platform sunos on host solaris10 is using the discovered Python interpreter at /opt/csw/bin/python2.6, but future installation of another Python interpreter could change this. See
https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more information.
ok: [solaris10]

TASK [create temporary directory] *******************************************************************************************************************************************************************************
ok: [solaris10] => (item=/tmp/ansible-scripts)

TASK [copy script to remote hosts] ******************************************************************************************************************************************************************************
ok: [solaris10] => (item=./harden_run.pl)
changed: [solaris10] => (item=./harden_ctl_sol.conf)

TASK [run harden script] ****************************************************************************************************************************************************************************************
changed: [solaris10]

TASK [debug] ****************************************************************************************************************************************************************************************************
ok: [solaris10] => {
    "hdout.stdout_lines": [
        "run_command:/bin/uname -s",
        "run_command:/bin/uname -r",
        "OS_NAME: SunOS, OS_RELEASE: 5.10",
        "",
        "Audit Points:",
        "D.3.1.1. Create User Warning Banner:cat /etc/issue:$banner_msg{\"/etc/issue\"}=\"PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\\n\"",
        "E.4.3.11. Set SSH Banner:grep \"^Banner\" /etc/ssh/sshd_config:$sshd_parameters{\"Banner \"}=\"/etc/issue\"",
        "E.1.1.9 Set Parameters Maximum Repeat Password:grep \"^MAXREPEATS=0\" /etc/default/passwd:$pam_cfg{\"/etc/default/passwd\"}{\"MAXREPEATS\"}=\"=2\"",
        "Parameters :",
        "recommended banner message : /etc/issue-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.",
        "",
        "recommended PAM : /etc/default/passwd-HASH(0x817ab0c)",
        "recommended shadow : ",
        "recommended sshd parameters : Banner -/etc/issue",
        "Execution :",
        "---Add Banner---",
        "backup copy /etc/issue,/etc/nmc_backup/issue.202012080634",
        "writing:/etc/issue",
        "---PAM Configuration---",
        "backup copy /etc/default/passwd,/etc/nmc_backup/passwd.202012080634",
        "reading:/etc/default/passwd",
        "writing:/etc/default/passwd",
        "---SSH Configuration---",
        "backup copy /etc/ssh/sshd_config,/etc/nmc_backup/sshd_config.202012080634",
        "reading:/etc/ssh/sshd_config",
        "writing:/etc/ssh/sshd_config",
        "run_command:/usr/sbin/pkgchk -f -n -p /etc/ssh/sshd_config",
        "run_command:/usr/sbin/svcadm restart svc:/network/ssh"
    ]
}

PLAY RECAP ******************************************************************************************************************************************************************************************************
solaris10                  : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0

doni@LAPTOP-OPP19HPH:~/Scripts/hardening$
```

Menjalankan hardening :

```
[root@centos7 ansible-scripts]# ./harden_run.pl -c=harden_ctl_el7.conf -e
run_command:/bin/uname -s
run_command:/bin/uname -r
OS_NAME: Linux, OS_RELEASE: el7
Audit Points:
B.4.1.1. Business Use Notice Banner:cat /etc/issue:$banner_msg{"/etc/issue"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
B.4.1.2. Business Use Notice Banner:cat /etc/issue.net:$banner_msg{"/etc/issue.net"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
D.3.2.11. Ensure SSH Banner file is configured:grep "^Banner" /etc/ssh/sshd_config:$sshd_parameters{"Banner "}="/etc/issue"
D.1.1.1. Ensure Minimum Password Length is 8:grep ^PASS_MIN_LEN /etc/login.defs:$user_cfg{"PASS_MIN_LEN"}="   8"
D.1.1.2. Ensure password expiration is 30 days:grep ^PASS_MAX_DAYS /etc/login.defs:$user_cfg{"PASS_MAX_DAYS"}="   30"
D.1.1.5. Ensure maximum number of failed password is 5:grep "^MaxAuthTries" /etc/ssh/sshd_config:$sshd_parameters{"MaxAuthTries "}="5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
Parameters :
recommended banner message : /etc/issue.net-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.
-/etc/issue-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.

recommended PAM : /etc/pam.d/password-auth-HASH(0x1ef7228)-/etc/pam.d/system-auth-HASH(0x20d5bb0)
recommended shadow : PASS_MAX_DAYS-   30-PASS_MIN_LEN-   8
recommended sshd parameters : Banner -/etc/issue-MaxAuthTries -5
Execution :
---Add Banner---
backup copy /etc/issue.net,/etc/nmc_backup/issue.net.202012080809
writing:/etc/issue.net
backup copy /etc/issue,/etc/nmc_backup/issue.202012080809
writing:/etc/issue
---PAM Configuration---
backup copy /etc/pam.d/password-auth,/etc/nmc_backup/password-auth.202012080809
reading:/etc/pam.d/password-auth
writing:/etc/pam.d/password-auth
backup copy /etc/pam.d/system-auth,/etc/nmc_backup/system-auth.202012080809
reading:/etc/pam.d/system-auth
writing:/etc/pam.d/system-auth
---Shadow Configuration---
backup copy /etc/login.defs,/etc/nmc_backup/login.defs.202012080809
reading:/etc/login.defs
writing:/etc/login.defs
---SSH Configuration---
backup copy /etc/ssh/sshd_config,/etc/nmc_backup/sshd_config.202012080809
reading:/etc/ssh/sshd_config
writing:/etc/ssh/sshd_config
run_command:/bin/systemctl reload sshd
[root@centos7 ansible-scripts]#
```

Menjalankan Rollback ke state sebelum Hardening saat ini:

```
[root@centos7 ansible-scripts]# ./harden_run.pl -c=harden_ctl_el7.conf -e -r
run_command:/bin/uname -s
run_command:/bin/uname -r
OS_NAME: Linux, OS_RELEASE: el7
Audit Points:
B.4.1.1. Business Use Notice Banner:cat /etc/issue:$banner_msg{"/etc/issue"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
B.4.1.2. Business Use Notice Banner:cat /etc/issue.net:$banner_msg{"/etc/issue.net"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
D.3.2.11. Ensure SSH Banner file is configured:grep "^Banner" /etc/ssh/sshd_config:$sshd_parameters{"Banner "}="/etc/issue"
D.1.1.1. Ensure Minimum Password Length is 8:grep ^PASS_MIN_LEN /etc/login.defs:$user_cfg{"PASS_MIN_LEN"}="   8"
D.1.1.2. Ensure password expiration is 30 days:grep ^PASS_MAX_DAYS /etc/login.defs:$user_cfg{"PASS_MAX_DAYS"}="   30"
D.1.1.5. Ensure maximum number of failed password is 5:grep "^MaxAuthTries" /etc/ssh/sshd_config:$sshd_parameters{"MaxAuthTries "}="5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
Parameters :
recommended banner message : /etc/issue.net-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.
-/etc/issue-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.

recommended PAM : /etc/pam.d/password-auth-HASH(0x1c2b228)-/etc/pam.d/system-auth-HASH(0x1e09af0)
recommended shadow : PASS_MAX_DAYS-   30-PASS_MIN_LEN-   8
recommended sshd parameters : Banner -/etc/issue-MaxAuthTries -5
Execution :
---Add Banner---
finding issue.net file
restore last copy /etc/nmc_backup/issue.net.202012080809,/etc/issue.net
finding issue file
restore last copy /etc/nmc_backup/issue.net.202012080809,/etc/issue
---PAM Configuration---
finding password-auth file
restore last copy /etc/nmc_backup/password-auth.202012080809,/etc/pam.d/password-auth
finding system-auth file
restore last copy /etc/nmc_backup/system-auth.202012080809,/etc/pam.d/system-auth
---Shadow Configuration---
finding login.defs file
restore last copy /etc/nmc_backup/login.defs.202012080809,/etc/login.defs
---SSH Configuration---
finding sshd_config file
restore last copy /etc/nmc_backup/sshd_config.202012080809,/etc/ssh/sshd_config
run_command:/bin/systemctl reload sshd
[root@centos7 ansible-scripts]#
```

Menjalankan Rollback ke state semula sebelum beberapa hardening dijalankan:
```
[root@centos7 ansible-scripts]# ./harden_run.pl -c=harden_ctl_el7.conf -e -r=*
run_command:/bin/uname -s
run_command:/bin/uname -r
OS_NAME: Linux, OS_RELEASE: el7
Audit Points:
B.4.1.1. Business Use Notice Banner:cat /etc/issue:$banner_msg{"/etc/issue"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
B.4.1.2. Business Use Notice Banner:cat /etc/issue.net:$banner_msg{"/etc/issue.net"}="PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.\n"
D.3.2.11. Ensure SSH Banner file is configured:grep "^Banner" /etc/ssh/sshd_config:$sshd_parameters{"Banner "}="/etc/issue"
D.1.1.1. Ensure Minimum Password Length is 8:grep ^PASS_MIN_LEN /etc/login.defs:$user_cfg{"PASS_MIN_LEN"}="   8"
D.1.1.2. Ensure password expiration is 30 days:grep ^PASS_MAX_DAYS /etc/login.defs:$user_cfg{"PASS_MAX_DAYS"}="   30"
D.1.1.5. Ensure maximum number of failed password is 5:grep "^MaxAuthTries" /etc/ssh/sshd_config:$sshd_parameters{"MaxAuthTries "}="5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.6. Ensure password reuse is limited to 5:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/password-auth:$pam_cfg{"/etc/pam.d/password-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
D.1.1.7. Ensure password hashing algorithm is SHA-512:egrep '^password\s+sufficient\s+pam_unix.so' /etc/pam.d/system-auth:$pam_cfg{"/etc/pam.d/system-auth"}{"password    sufficient    pam_unix.so"}=" sha512 remember=5"
Parameters :
recommended banner message : /etc/issue.net-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.
-/etc/issue-PERINGATAN: Anda akan melakukan akses terhadap komputer yang dilindungi sesuai dengan UU ITE Indonesia. Penggunaan akses yang tidak terotorisasi ke komputer atau program atau data yang dilindungi akan dikenakan sanksi sesuai dengan Undang-Undang yang berlaku.

recommended PAM : /etc/pam.d/password-auth-HASH(0x1eed228)-/etc/pam.d/system-auth-HASH(0x20cbab0)
recommended shadow : PASS_MAX_DAYS-   30-PASS_MIN_LEN-   8
recommended sshd parameters : Banner -/etc/issue-MaxAuthTries -5
Execution :
---Add Banner---
finding issue.net.* file
restore 1st copy /etc/nmc_backup/issue.net.202012080624,/etc/issue.net
finding issue.* file
restore 1st copy /etc/nmc_backup/issue.202012080624,/etc/issue
---PAM Configuration---
finding password-auth.* file
restore 1st copy /etc/nmc_backup/password-auth.202012080649,/etc/pam.d/password-auth
finding system-auth.* file
restore 1st copy /etc/nmc_backup/system-auth.202012080649,/etc/pam.d/system-auth
---Shadow Configuration---
finding login.defs.* file
restore 1st copy /etc/nmc_backup/login.defs.202012080649,/etc/login.defs
---SSH Configuration---
finding sshd_config.* file
restore 1st copy /etc/nmc_backup/sshd_config.202012080624,/etc/ssh/sshd_config
run_command:/bin/systemctl reload sshd
[root@centos7 ansible-scripts]#
```

License
-------

N/A

Author Information
------------------

Author: doniarto@gmail.com
