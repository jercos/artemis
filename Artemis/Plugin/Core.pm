package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
use Time::ParseDate;
sub new{
	my $class = shift;
	my $self = {
		commands =>{
test => sub{return "Test passed!"},
say => sub{return shift if defined pop->level},
quit => sub{return if pop->level<=500;pop->disconnect()},
load => sub{return if pop->level<=500;return "Success" if pop->{main}->load(shift);return "Failure"},
quote => sub{my($a,$s,$c,$m)=@_;return if $m->level<=500;my($ind,$raw)=split(/ +/,$a,2);if(0+$ind eq $ind){$c->{main}{connections}[$ind]->send($raw)}else{$c->send($ind." ".$raw)}},
login => sub{my($a,$s,$c,$m)=@_;my($login,$pass)=split(/ +/,$a,2);return "UTTER FAILURE" if $c->{main}{pass}{$login} ne sha1_base64($pass);return "You are now logged in as ".($c->{main}{logins}{lc $m->token}=$login)},
mkuser => \&mkuser,
rmuser => sub{;},
passwd => \&passwd,
'eval' => sub{my($a,$s,$c,$m)=@_;return unless $m->level>500;return eval($a) || $@;},
whoami => sub{my $msg = pop;return $msg->user.", you are ".(defined($msg->level)?"logged in, at level ".$msg->level.".":"not logged in.")},
gettoken => sub{my $msg = pop;return $msg->user.", your token is '".$msg->token."'"},
time => sub{return scalar localtime()},
timer => sub{my($a,$s,$c,$m)=@_;return "Try again, with less fail this time." unless $a=~/^(\d+[hms]?)(?: *(.{0,60}))$/;$s->{timers}{time()+timetosecs($1)}=[$c,$m,$2];return "Timer added."},
beep => sub{my($a,$s,$c,$m)=@_;my$t;return "Fail." unless $a=~/^(.*) {2,}(.*)$/ && ($t=parsedate($1));$s->{timers}{$t}=[$c,$m,$2];return "Set a timer named \"$2\" for ".localtime($t)},
beepcos => sub{my($a,$s,$c,$m)=@_;return unless $m->level>512;return "Beeping Jeremy, PID of ".open(BEEP,"-|","/home/jercos/bin/beepcos")},
		},
		timers => {},
	};
	return bless($self,$class);
}
sub Process{
	my $self = shift;
	for my $timer (keys %{$self->{timers}}){
		my($conn,$msg,$name) = @{$self->{timers}{$timer}};
		if($timer <= time){
			$conn->message($msg->to,$msg->user.", your timer".($name?", '$name' ":" ")."has expired.");
			open(BEEP,"-|","/home/jercos/bin/beepcos") if $msg->user eq "jercos";
			delete($self->{timers}{$timer});
		}
	}
}
sub timetosecs{
	my $time = shift;
	$time =~ s/^(.*)([hm])$/($2 eq "h"?60*60:60)*$1/e;
	$time =~ y/0-9//dc;
	return $time;
}
sub mkuser{
	my($input,$self,$conn,$msg)=@_;
	return "You must construct additional pylons." unless defined $msg->level;
	my($login,$level,$pass)=split(/ +/,$input,3);
	return "You must spawn more overlords." unless $msg->level > $conn->{main}{users}{$login};
	$conn->{main}{pass}{$login}=sha1_base64($pass);
	$conn->{main}{users}{$login}=($msg->level < $level)?$msg->level-1:$level;
}
sub passwd{
	my($input,$self,$conn,$msg)=@_;
	return "You are not logged in, sorry." unless defined $msg->level;
	return("Hash for ".$msg->user." set to ".($conn->{main}{pass}{$msg->user}=sha1_base64($input)));
}
sub input{
	my $self = shift;
	my($conn,$msg) = @_;
	$conn->send("KICK ".$msg->via." ".$msg->user." :You down with Arty? YEAH YOU BEEP ME.") if $msg->text =~ /\x07/ and "Artemis::Connection::Unreal" eq ref $conn;
	$conn->message($msg->to,":D") if $msg->text =~ /^botsnack$/i;
	$conn->message($msg->to,"Hello, ".$msg->user."!") if $msg->text =~ /^(hello|hi|howdy)[, ]+art(y|emis)?/i;
	return unless $msg->pm && $msg->text =~ /^([^ ]+) ?(.*?)$/;
	return if time - $self->{main}{floodprot}{$msg->token} < 4;
	$self->{main}{floodprot}{$msg->token}=time;
	my($cmd,$args)=($1,$2);
	$conn->message($msg->to,$self->{commands}{$cmd}($args,$self,$conn,$msg)) if ref($self->{commands}{$1}) eq "CODE";
}
1;
