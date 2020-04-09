#!/bin/bash
# Menu driven script for administering Postfix + Dovecot with MySQL back-end
# Author: Daniel Zhelev @ https://zhelev.biz
# SET MAIL SERVERS - need to have ssh to them
MAIL_SERVERS=""
# Since we are using mysql replication we need to do most of the things on only 1 node
MASTER_MAIL=""
DB_USER=""
DB_PASSWORD=""
DB_NAME=""

#####################################################

# SSH function
SSH()
{
        /bin/ssh -q -o ConnectTimeout=10 -o ConnectionAttempts=1 $@
}


# SSH test function
SSH_TEST()
{
  for MAIL in $MAIL_SERVERS
   do
        SSH $MAIL "/bin/test -e /etc/hosts"
         UP=$?
          if [ $UP -ne 0 ]
           then
            dialog --title "NOTICE" \
            --backtitle "Postfix Admin" \
            --msgbox  "Cannot connect to server \"$MAIL\" " 7 60
            return 1
          fi
   done
}


# Tmp file for the menu
INPUT=/tmp/menu.sh.$$

# Storage file for displaying cal and date command output
OUTPUT=/tmp/output.sh.$$

# trap and delete temp files
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

#
# Purpose - display output using msgbox
#  $1 -> set msgbox height
#  $2 -> set msgbox width
#  $3 -> set msgbox title
#
function display_output(){
        local h=${1-10}                 # box height default 10
        local w=${2-41}                 # box width default 41
        local t=${3-Output}     # box title
        dialog --backtitle "Postfix admin" --title "${t}" --clear --msgbox "$(<$OUTPUT)" ${h} ${w}
}





#
# Purpose - add domain to postfix conf
#
function add_domain(){
 # show an inputbox
 dialog --title "Add domain" \
    --backtitle "Postfix Admin" \
    --inputbox "Domain address " 8 60 2>$OUTPUT

  # Return to privious menu in case of ESC or Cancel
   qresponse=$?
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 # get data stored in $OUPUT using input redirection
 domain=$(<$OUTPUT)

 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want add domain \"$domain\"?" 7 60

  # Get exit status
  aresponse=$?
   case $aresponse in
     0)
       SSH_TEST || return 1
          if [[ -z "$domain" ]]; then
            dialog --title "Error" --msgbox 'Domain name empty. Aborting operation' 6 60
            return 1
          else

# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
INSERT INTO virtual_domains (name) VALUES  ('$domain');
INSERT INTO virtual_aliases (domain_id, source, destination) VALUES  ((select id from virtual_domains where name='$domain'), 'postmaster@$domain', 'postmaster');
INSERT INTO virtual_aliases (domain_id, source, destination) VALUES  ((select id from virtual_domains where name='$domain'), 'webmaster@$domain', 'webmaster');
INSERT INTO virtual_aliases (domain_id, source, destination) VALUES  ((select id from virtual_domains where name='$domain'), 'abuse@$domain', 'abuse');
INSERT INTO virtual_aliases (domain_id, source, destination) VALUES  ((select id from virtual_domains where name='$domain'), 'hostmaster@$domain', 'hostmaster');
EOF

          fi

        ;;
     1) echo "Operation aborted";;
     255) echo "[ESC] key pressed.";;
   esac

}





#
# Purpose - remove domain from postfix
#
function remove_domain(){
 # show an inputbox
 dialog --title "Remove domain" \
    --backtitle "Postfix Admin" \
    --inputbox "Domain address " 8 60 2>$OUTPUT

  # Return to privious menu in case of ESC or Cancel
   qresponse=$?
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 # get data stored in $OUPUT using input redirection
 rdomain=$(<$OUTPUT)

 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want REMOVE domain \"$rdomain\"?" 7 60

  # Get exit status
   aresponse=$?
     case $aresponse in
       0)
       SSH_TEST || return 1
         if [[ -z "$rdomain" ]]; then
            dialog --title "Error" --msgbox 'Domain name empty. Aborting operation' 6 60
            return 1
          else

# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
DELETE FROM virtual_aliases WHERE domain_id=(select id from virtual_domains where name='$rdomain');
DELETE FROM virtual_users WHERE domain_id=(select id from virtual_domains where name='$rdomain');
DELETE FROM virtual_domains WHERE name='$rdomain';
EOF

          fi
          ;;
       1) echo "Operation aborted";;
       255) echo "[ESC] key pressed.";;
     esac

}




#
# Purpose - add user
# NOTICE: not using the temp file due to security reasons!
function add_user(){
 # show an inputbox
 exec 3>&1;
 email=$(dialog --title "Add user" --backtitle "Postfix Admin" --inputbox "Email address " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 domid=$(dialog --title "Add user" --backtitle "Postfix Admin" --inputbox "User Domain " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 epass=$(dialog --title "Add user" --backtitle "Postfix Admin" --insecure --passwordbox "Password " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac



 exec 3>&-;



 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want add user \"$email\"?" 7 60

  # Get exit status
  aresponse=$?
   case $aresponse in
     0)
       SSH_TEST || return 1
        if [[ -z "$email" && -z "$epass" && -z "$domid" ]]; then
            dialog --title "Error" --msgbox 'User name, domain id or password empty. Aborting operation.' 6 60
            return 1
          else
           if [[ $email == *"@"* ]]
            then

# Do NOT insert spaces or tabs here, it breaks
## Check if domain exists
RCOUNT=$(SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -AN -B -e "select COUNT(1) from virtual_domains where name='$domid'"
EOF
)

if [ ${RCOUNT} -eq 0 ]
then
dialog --title "Error" --msgbox 'Domain not found on this system. Aborting operation.' 6 60
return 1
fi


# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
INSERT INTO virtual_users  (domain_id, password , email) VALUES ((select id from virtual_domains where name='$domid'), ENCRYPT('$epass', CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))) , '$email');
EOF

              for MAIL in $MAIL_SERVERS
               do
                SSH $MAIL "dovecot replicator replicate $email" >/dev/null
               done


              else
                dialog --title "Error" --msgbox 'User name is missing a @. Aborting.' 6 60
                return 1
           fi
       fi

        ;;
     1) echo "Operation aborted";;
     255) echo "[ESC] key pressed.";;
   esac

}

#
# Purpose - add alias
# NOTICE: not using the temp file due to security reasons!
function add_alias(){
 # show an inputbox
 exec 3>&1;

 edomid=$(dialog --title "Add alias" --backtitle "Postfix Admin" --inputbox "Domain name of the alias " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 pemail=$(dialog --title "Add alias" --backtitle "Postfix Admin" --inputbox "Primary Email address " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 ealias=$(dialog --title "Add alias" --backtitle "Postfix Admin" --inputbox "Alias Email address " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 exec 3>&-;



 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want add alias \"$ealias\"?" 7 60

  # Get exit status
  aresponse=$?
   case $aresponse in
     0)
        SSH_TEST || return 1
         if [[ -z "$pemail" && -z "$ealias" ]]; then
            dialog --title "Error" --msgbox 'User name or alias empty. Aborting operation.' 6 60
            return 1
          else
             if [[ $pemail == *"@"* && $ealias == *"@"* ]]
              then

# Do NOT insert spaces or tabs here, it breaks
## Check if domain exists
RCOUNT=$(SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -AN -B -e "select COUNT(1) from virtual_domains where name='$edomid'"
EOF
)

if [ ${RCOUNT} -eq 0 ]
then
dialog --title "Error" --msgbox 'Domain not found on this system. Aborting operation.' 6 60
return 1
fi


# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
INSERT INTO virtual_aliases (domain_id, source, destination) VALUES  ((select id from virtual_domains where name='$edomid'), '$ealias', '$pemail');
EOF

              else
               dialog --title "Error" --msgbox 'User name or alias is missing a @. Aborting.' 6 60
               return 1
              fi
          fi

        ;;
     1) echo "Operation aborted";;
     255) echo "[ESC] key pressed.";;
   esac

}

#
# Purpose - change password for user
# NOTICE: not using the temp file due to security reasons!
function ch_pass(){
 # show an inputbox
 exec 3>&1;
 email=$(dialog --title "Change password" --backtitle "Postfix Admin" --inputbox "Email address " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 epass=$(dialog --title "Change password" --backtitle "Postfix Admin" --insecure --passwordbox "Password " 8 60 2>&1 1>&3)
 qresponse=$?
   # Return to privious menu in case of ESC or Cancel
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 exec 3>&-;



 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want to change the password for user \"$email\"?" 7 60

  # Get exit status
  aresponse=$?
   case $aresponse in
     0)
       SSH_TEST || return 1
         if [[ -z "$email" && -z "$epass" ]]; then
            dialog --title "Error" --msgbox 'User name or password empty. Aborting operation.' 6 60
            return 1
          else
             if [[ $email == *"@"* ]]
              then
              for MAIL in $MAIL_SERVERS
               do
# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
UPDATE virtual_users SET password=ENCRYPT('$epass', CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))) WHERE email='$email';
EOF
               done
              else
               dialog --title "Error" --msgbox 'User name is missing a @. Aborting.' 6 60
               return 1
              fi
          fi

        ;;
     1) echo "Operation aborted";;
     255) echo "[ESC] key pressed.";;
   esac

}

#
# Purpose - remove user from postfix
#
function remove_user(){
 # show an inputbox
 dialog --title "Remove user" \
    --backtitle "Postfix Admin" \
    --inputbox "Email address " 8 60 2>$OUTPUT

  # Return to privious menu in case of ESC or Cancel
   qresponse=$?
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 # get data stored in $OUPUT using input redirection
 remail=$(<$OUTPUT)

 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want REMOVE user \"$remail\"?" 7 60

  # Get exit status
   aresponse=$?
     case $aresponse in
       0)
       SSH_TEST || return 1
         if [[ -z "$remail" ]]; then
            dialog --title "Error" --msgbox 'User name empty. Aborting operation.' 6 60
            return 1
          else
             if [[ $remail == *"@"* ]]
              then

# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
delete from virtual_users where email='$remail';
delete from virtual_aliases where destination='$remail';
EOF

              for MAIL in $MAIL_SERVERS
               do
                 SSH $MAIL "dovecot replicator remove $remail"
               done

              else
               dialog --title "Error" --msgbox 'User name is missing a @. Aborting.' 6 60
               return 1
              fi
          fi

          ;;
       1) echo "Operation aborted";;
       255) echo "[ESC] key pressed.";;
     esac

}

#
# Purpose - remove user alias from postfix
#
function remove_alias(){
 # show an inputbox
 dialog --title "Remove alias" \
    --backtitle "Postfix Admin" \
    --inputbox "Alias Email address " 8 60 2>$OUTPUT

  # Return to privious menu in case of ESC or Cancel
   qresponse=$?
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 # get data stored in $OUPUT using input redirection
 raemail=$(<$OUTPUT)

 dialog --title "Confirm" \
  --backtitle "Postfix Admin" \
  --yesno "Are you sure you want REMOVE alias \"$raemail\"?" 7 60

  # Get exit status
   aresponse=$?
     case $aresponse in
       0)
            SSH_TEST || return 1
             if [[ $raemail == *"@"* ]]
              then
# Do NOT insert spaces or tabs here, it breaks
SSH $MASTER_MAIL << EOF
mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -B
delete from virtual_aliases where source='$raemail';
EOF
              else
               dialog --title "Error" --msgbox 'User alias is missing a @. Aborting.' 6 60
               return 1
              fi

          ;;
       1) echo "Operation aborted";;
       255) echo "[ESC] key pressed.";;
     esac

}

#
# Purpuse - check the replication status for specific user
#
function check_user_replication(){
 # show an inputbox
 dialog --title "Check replication" \
    --backtitle "Postfix Admin" \
    --inputbox "User Email address " 8 60 2>$OUTPUT

  # Return to privious menu in case of ESC or Cancel
   qresponse=$?
   case $qresponse in
     1) return 0;;
     255) return 0;;
   esac

 # get data stored in $OUPUT using input redirection
 repmail=$(<$OUTPUT)

            SSH_TEST || return 1
             if [[ $repmail == *"@"* ]]
             then
                   SSH_TEST || return 1
                   echo >$OUTPUT
                   for MAIL in $MAIL_SERVERS
                    do
                      echo "Replication on $MAIL:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      SSH $MAIL "dovecot replicator status $repmail 1>&2" >>$OUTPUT 2>&1
                      echo " " >>$OUTPUT
                    done
                   display_output 30 70 "Replication status"
              else
               dialog --title "Error" --msgbox 'User Email is missing a @. Aborting.' 6 60
               return 1
              fi
}


################################### KEEP AT THE END

#
# Purpuse - user admin menu
#
user_admin() {
while true
do
dialog --clear --backtitle "Postfix Admin" \
--title "[ User Admin ]" \
--menu "Choose the TASK" 20 60 9 \
Add\ user "Add new user to postfix" \
Add\ alias "Add alias for user" \
Change\ password "Change the password for user" \
Remove\ user "Remove user from postfix" \
Remove\ alias "Remove alias from postfix" \
Check\ user\ replication "Check the replication for user" \
List\ users "List all users" \
Back "" 2>"${INPUT}"

usermretval=$?
usermenuitem=$(<"${INPUT}")

case $usermretval in
  0)
     case $usermenuitem in
                Add\ user) add_user;;
                Add\ alias) add_alias;;
                Change\ password) ch_pass;;
                Remove\ user) remove_user;;
                Remove\ alias) remove_alias;;
                List\ users)
                   SSH_TEST || return 1
                   echo >$OUTPUT
                   for MAIL in $MAIL_SERVERS
                    do
                      echo "Users on $MAIL:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      SSH $MAIL "mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -e 'select id,domain_id,email from virtual_users' -B" >>$OUTPUT
                      echo " " >>$OUTPUT
                    done
                   display_output 50 50 "Users"
                   ;;
                Check\ user\ replication) check_user_replication;;
                Back) return 0;;
     esac
     ;;
  1)
     break
     ;;
  255)
     break
     ;;

esac
done
}

#
# Purpuse - domain admin menu
#
domain_admin() {
while true
do
dialog --clear --backtitle "Postfix Admin" \
--title "[ Domain Admin ]" \
--menu "Choose the TASK" 15 55 5 \
Add\ domain "Add new domain to postfix" \
Remove\ domain "Remove domain from postfix" \
List\ domains "List all domains from postfix" \
Replication\ status "Check replication status" \
Back "" 2>"${INPUT}"

domainmretval=$?
domainmenuitem=$(<"${INPUT}")

case $domainmretval in
  0)
     case $domainmenuitem in
                Add\ domain) add_domain;;
                Remove\ domain) remove_domain;;
                List\ domains)
                   SSH_TEST || return 1
                   echo >$OUTPUT
                   for MAIL in $MAIL_SERVERS
                    do
                      echo "Domains on $MAIL:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      SSH $MAIL "mysql -u$DB_USER -p$DB_PASSWORD -D$DB_NAME -e 'select id,name from virtual_domains' -B" >>$OUTPUT
                      echo " " >>$OUTPUT
                    done
                   display_output 50 50 "Domains"
                   ;;
                Replication\ status)
                   SSH_TEST || return 1
                   echo >$OUTPUT
                   for MAIL in $MAIL_SERVERS
                    do
                      echo "Replication on $MAIL:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      echo "Dovecot:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      SSH $MAIL "dovecot replicator status" >>$OUTPUT
                      echo " " >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      echo "MySQL:" >>$OUTPUT
                      echo "**************" >>$OUTPUT
                      SSH $MAIL "/etc/periodic/security/mysql_replication_status.pl" >>$OUTPUT
                      echo " " >>$OUTPUT
                      echo " " >>$OUTPUT
                    done
                   display_output 50 50 "Replication status"
                   ;;
                Back) return 0;;
     esac
     ;;
  1)
     break
     ;;
  255)
     break
     ;;

esac
done
}


#####################################################
#
# set infinite loop
#
while true
do

### display main menu ###
dialog --clear --backtitle "Postfix Admin" \
--title "[ Postfix Admin ]" \
--menu "You can use the UP/DOWN arrow keys, the first \n\
letter of the choice as a hot key, or the \n\
number keys 1-9 to choose an option.\n\
Choose the TASK" 15 70 3 \
User\ administration "Add or remove user from postfix" \
Domain\ administration "Add or remove domain from postfix" \
Exit "Exit to the shell" 2>"${INPUT}"

mretval=$?
menuitem=$(<"${INPUT}")

case $mretval in
  0)
     case $menuitem in
                User\ administration) user_admin;;
                Domain\ administration) domain_admin;;
                Exit) echo "Bye"; break;;
     esac
     ;;
  1)
     break
     ;;
  255)
     break
     ;;

esac

done

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
