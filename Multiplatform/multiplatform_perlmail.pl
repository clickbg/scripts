#!/usr/bin/perl
use MIME::Lite;
use Getopt::Long;
GetOptions ("server=s" => \$MAILSERVER,
              "subject=s"   => \$SUBJECT,
              "recepient=s"  => \@RECEPIENTS,
              "sender=s"   =>  \$SENDER,
              "attach=s"   =>\@ATTACHMENTS,
              "html=s"     =>\@HTML,
              "type=s"     =>\$TYPE)
  or die("Error in command line arguments\n");
#print "\nserver:$MAILSERVER\nsubbject:$SUBJECT\nrec:@RECEPIENTS\n";
#print join(' ',@RECEPIENTS);
$TYPE1=$TYPE;
if(length($TYPE1)<4){
        $TYPE1='multipart/mixed';
}

$msg= MIME::Lite->new(
        From => $SENDER,
        To => [join(',',@RECEPIENTS)] ,
        Subject => $SUBJECT,
        Type => $TYPE1
        );
$message="";
while(<>){
$message.=$_;

}
#print "\nmsg:\n$message\n";
$msg->attach(Type=>'TEXT',Data=>$message);
foreach $att (@ATTACHMENTS){
#  print "\n file: $att";
#  print "\n".`file -bi $att`;
  $msg->attach(Type=>`file -bi $att`,Path=>$att,Disposition=>'attachment') ;
}
foreach $att (@HTML){
#  print "\n file: $att";
#  print "\n".`file -bi $att`;
  $msg->attach(Type=>`file -bi $att`,Path=>$att,Disposition=>'inline') ;
}

MIME::Lite->send('smtp',$MAILSERVER);
$msg->send() or die("unable to send mail");
