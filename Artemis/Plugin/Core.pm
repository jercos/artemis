package Artemis::Plugin::Core;
use Digest::SHA qw(sha1_base64);
sub new{
	my $class = shift;
	my $self = {
		test => sub{return "Tested true. Yay!"},
		say => sub{return shift},
		quit => sub{my($msg, $conn, $level)=@_;return unless $level >500;$conn->disconnect()},
		quote => sub{my($msg, $conn, $level)=@_;return unless $level>500;my($ind,$raw)=split(/ +/,$msg,2);if($ind+0 eq $ind){$conn->{main}{connections}[$ind]->send($raw)}else{$conn->send($msg)}},
		login => sub{my($msg, $conn, $level, $user, $token)=@_;my($user,$pass)=split(/ +/,$msg,2);return unless $conn->{main}{pass}{$user} eq sha1_base64($pass);$conn->{main}{logins}{$token}=$user},
		eval => sub{my($msg, $conn, $level)=@_;return unless $level>500;my $val = eval $msg;return $@?$@:$val},
		whoami => sub{my($msg,$conn,$level,$user,$token)=@_;return "you are logged in as $user, your level is $level" if $level;return "you are not logged in, $user."},
		time => sub{return scalar localtime()}
	};
	return bless($self,$class);
}
sub input{
	my $self = shift;
	my($conn,$to,$name,$msg,$pm,$user,$level,$token) = @_;
	my $nick = $conn->{nick};
	return unless $msg =~ /^\)([^ ]+) ?(.*?)$/ || $msg =~ /^$nick[ :,]+([^ ]+) ?(.*?)$/i || ($pm && $msg =~ /^([^ ]+) ?(.*?)$/);
	return if time - $self->{main}{floodprot}{$token} < 4;
	$self->{main}{floodprot}{$token}=time;
	$conn->message($to,$self->{$1}($2,$conn,$level,$user,$token)) if exists $self->{$1} && ref($self->{$1}) eq "CODE";
}
1;
