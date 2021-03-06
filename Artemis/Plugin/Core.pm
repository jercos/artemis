package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
use Time::ParseDate;
use DateTime;
use URI::Escape;
sub new{
	my $class = shift;
	my $self = {
		commands =>{
test => sub{return "Test passed!"},
say => sub{return shift if defined pop->level},
google => sub{my $a=uri_escape(shift,"^a-zA-Z0-9 ");$a=~tr/ /+/;return "http://google.com/search?q=".$a},
quit => sub{return if pop->level<=500;pop->disconnect()},
load => sub{return if pop->level<=500;return "Success" if pop->{main}->load(shift);return "Failure"},
quote => sub{my($a,$s,$c,$m)=@_;return if $m->level<=500;my($ind,$raw)=split(/ +/,$a,2);if(0+$ind eq $ind){$c->{main}{connections}[$ind]->send($raw)}else{$c->send($ind." ".$raw)}},
login => sub{my($a,$s,$c,$m)=@_;my($login,$pass)=split(/ +/,$a,2);return "UTTER FAILURE" if $c->{main}{pass}{$login} ne sha1_base64($pass);return "You are now logged in as ".($c->{main}{logins}{lc $m->token}=$login)},
logout => sub{my($a,$s,$c,$m)=@_;return "You are now logged out, ".(delete $c->{main}{logins}{lc $m->token})},
mkuser => \&mkuser,
rmuser => sub{;},
passwd => \&passwd,
'eval' => sub{my($args,$s,$c,$m)=@_;return unless $m->level>500;return eval{local$SIG{INT}=sub{die "Caught Ctrl-C\n"};my$r=eval($args)||$@}},
whoami => sub{my $msg = pop;return $msg->user.", you are ".(defined($msg->level)?"logged in, at level ".$msg->level.".":"not logged in.")},
gettoken => sub{my $msg = pop;return $msg->user.", your token is '".$msg->token."'"},
time => sub{eval{my $d =DateTime->now(time_zone=>(shift||'local'))->strftime("%a %b %e %T %Y %Z")}||$@;},
timer => sub{my($a,$s,$c,$m)=@_;return "Try again, with less fail this time." unless $a=~/^((?:\d+[hms]?)+)(?: *(.{0,60}))$/;$s->{timers}{time()+timetosecs($1)}=[$c,$m,$2];return "Timer added."},
beep => sub{my($a,$s,$c,$m)=@_;my$t;return "Fail." unless $a=~/^(.*) {2,}(.*)$/ && ($t=parsedate($1));$s->{timers}{$t}=[$c,$m,$2];return "Set a timer named \"$2\" for ".localtime($t)},
beepcos => sub{my($a,$s,$c,$m)=@_;return unless $m->level>512;return "Beeping Jeremy, squirrel of ".open(BEEP,"-|","/home/jercos/bin/beepcos")},
bofh => sub{my($a,$s,$c,$m)=@_;open my $bofhh,'excuses.txt' or return "Excuses file not found.";return((<$bofhh>)[$a-1])if$a>0;my $bofh;rand($.)<1 and ($bofh="$.: $_") while <$bofhh>;return $bofh},
forge => sub{my($a,$s,$c,$m)=@_;return unless $m->level>512;my($cnum,$targ,$msg)=split(/ /,$a,3);print STDERR "Forging '$msg' at c$cnum $targ\n";$c->{main}->incoming($c->{main}{connections}[$cnum],Artemis::Message->new(level=>$m->level,user=>$m->user,text=>$msg,to=>$targ,via=>$targ,token=>$m->token,nick=>"artemis"))},
iksay => sub{join("",map{(ord()<127&&ord()>32)?chr(0xFEE0+ord):$_}split('',shift))}
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
	my @time = split/([hms])/,shift;
	return $time[0] if @time == 1;
	my $sum;
	$sum = shift @time if @time%2;
	while(@time>=2){
		(my$c,my$d,@time)=@time;
		$sum += $c if $d eq "s";
		$sum += $c*60 if $d eq "m";
		$sum += $c*3600 if $d eq "h";
	}
	return $sum;
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
	$conn->send("KICK ".$msg->via." ".$msg->user." :Never gonna give you up, never gonna send you BELs, never gonna run around and desert you...") if $msg->text =~ /\x07/ and "Artemis::Connection::Unreal" eq ref $conn;
	$conn->message($msg->to,":D") if $msg->text =~ /^botsnack$/i && $msg->pm;
	$conn->message($msg->to,"Hello, ".$msg->user."!") if $msg->text =~ /^(hello|hi|howdy)[, ]+art(y|emis)?/i;
	return unless $msg->pm && $msg->text =~ /^([^ ]+) ?(.*?)$/;
	return if time - $self->{main}{floodprot}{$msg->token} < 4 and $msg->level < 65535;
	$self->{main}{floodprot}{$msg->token}=time;
	my($cmd,$args)=($1,$2);
	$conn->message($msg->to,$self->{commands}{$cmd}($args,$self,$conn,$msg)) if ref($self->{commands}{$1}) eq "CODE";
}
1;
