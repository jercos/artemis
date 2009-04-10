package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
sub new{
	my $class = shift;
	my $self = {
		commands =>{
test => sub{return "Test passed!"},
say => sub{return shift},
quit => sub{my($msg, $conn, $level)=@_;return unless $level >500;$conn->disconnect()},
quote => sub{my($msg, $conn, $level)=@_;return unless $level>500;my($ind,$raw)=split(/ +/,$msg,2);if($ind+0 eq $ind){$conn->{main}{connections}[$ind]->send($raw)}else{$conn->send($msg)}},
login => sub{my($msg, $conn, $level, $user, $token)=@_;my($login,$pass)=split(/ +/,$msg,2);return "UTTER FAILURE" unless $conn->{main}{pass}{$login} eq sha1_base64($pass);return "You are now logged in as ".($conn->{main}{logins}{$token}=$login)},
eval => sub{my($msg, $conn, $level)=@_;return unless $level>500;my $val = eval $msg;return $@?$@:$val},
whoami => sub{my($msg,$conn,$level,$user,$token)=@_;return "you are logged in as $user, your level is $level" if $level;return "you are not logged in, $user."},
gettoken => sub{my($msg,$conn,$level,$user,$token)=@_;return "$user, your token is '$token'"},
time => sub{return scalar localtime()},
botsnack => sub{return ":D"},
		}
	};
	return bless($self,$class);
}
sub input{
	my $self = shift;
	my($conn,$to,$name,$msg,$pm,$user,$level,$token) = @_;
	my $nick = $conn->{nick};
	$conn->message($to,":D") if $msg =~ /^botsnack/i;
	return unless $msg =~ /^\)([^ ]+) ?(.*?)$/ || $msg =~ /^$nick[ :,]+([^ ]+) ?(.*?)$/i || ($pm && $msg =~ /^([^ ]+) ?(.*?)$/);
	return if time - $self->{main}{floodprot}{$token} < 4;
	$self->{main}{floodprot}{$token}=time;
	$conn->message($to,$self->{commands}{$1}($2,$conn,$level,$user,$token,$self)) if exists $self->{commands}{$1} && ref($self->{commands}{$1}) eq "CODE";
}
1;
