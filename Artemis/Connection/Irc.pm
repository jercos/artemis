package Artemis::Connection::Irc;
use IO::Socket;
use strict;
sub new{
	my $class = shift;
	my $self = {
		host=>"localhost",	#server to connect to
		port=>"6667",		#port to connect on
		nick=>"artemis",	#nick!user@host, Real name: realname, if you don't get it, ignore these.
		user=>"artemis",
		realname=>"Artemis v2.0, Jeremy Sturdivant (jercos)",
		serverpass=>undef,	#PASS to send
		nickpass=>undef,	#password to send to nickserv.
		autoconnect=>1,		#set to a false value to not immediately call $self->connect(), you'll have to call it later.
		onconnect=>sub{	#this will get called when up and running.
			my $self = shift;
			$self->send("JOIN :".join(",",@{$self->{autojoin}}));
			$self->send("MODE ".($self->{nick})." +B");
		},
		sock=>undef,		#this holds an IO::Socket::INET object, or an IO::Handle, or similar. anything that works inside readline()
		autojoin=>[],		#what channels do we want to join automatically?
		@_,			#and finally, suck up any key=>value pairs passed in, and overwrite default values.
	};
	bless($self,$class);
	$self->connect() if $self->{autoconnect};
	$self->{autoconnect}=0; #to facilitate cloning.
	return $self;
}
#I think this is self explanitory. disconnect if we're connected, then connect (potentially "reconnect")
sub connect{
	my $self = shift;
	#make sure we're dealing with a dead socket.
	$self->disconnect if defined($self->{sock}) && $self->{sock}->connected();
	#make a new socket
	$self->{sock} = IO::Socket::INET->new(
		PeerAddr=>$self->{host},
		PeerPort=>$self->{port},
		Blocking=>0,
	);
	#add our new socket to the select loop
	select('','','',0.1) while eof($self->{sock});
	$self->send("PASS :".$self->{serverpass}) if $self->{serverpass};
	$self->send("USER ".$self->{user}." - - :".$self->{realname},"NICK ".$self->{nick});
}
#we're done, y'all hear?
sub disconnect{
	my $self = shift;
	$self->send("QUIT :disconnect called :(\n");
	$self->{sock}->close();
}
#call this every once in a while, a second or two is suitable, but this should return in under a quarter of a second unless the socket was opened blocking.
sub Process{
	my $self = shift;
	while(defined(my $line = readline($self->{sock}) )){
		$line .= readline($self->{sock}) while !chomp $line;
		$self->irc($line);
	}
}
#a raw send, for exposing to the outside world, and shortening. Never call a Connection module's send() without checking the ref() to make sure it matches the protocol you expect.
sub send{
	my $self = shift;
	return 0 unless defined($self->{sock}) && $self->{sock}->connected();
	for(@_){
		my $x = "$_";
		$x =~ s/[\r\n]//g;
		printf STDERR "%02d:%02d:%02d  <-%s\n" ,(localtime)[2,1,0] ,$x;
		print {$self->{sock}} "$x\n";
	}
}
#data headed outward to the network. this defines the scheme for extra data for Artemis::outgoing
sub message{
	my $self = shift;
	return 0 unless defined($self->{sock}) && $self->{sock}->connected();
	my($replyto, $msg) = @_;
	for(map{substr $_,0,512}split(/[\r\n]+/,$msg)){
		printf STDERR "%02d:%02d:%02d <%s:%s> %s\n" ,(localtime)[2,1,0],$self->{nick} ,$replyto ,$_;
		print {$self->{sock}} "PRIVMSG $replyto :$_\n";
	}
}
#this now does the actual parsing of incoming messages :)
sub irc{
	my $self = shift;
	my $data = shift;
	$data =~ s/[\r\n]//g;
	my($special,$main,$longarg) = split(/^:| :/,$data,3);
	return $self->send($data) if $data =~ s/^PING/PONG/;
	printf STDERR "%02d:%02d:%02d special data: '%s'\n",(localtime)[2,1,0],$data if $special;
	return $self->{sock}->close() if $data =~ /^ERROR/;
	my($mask,$command,@args) = split(/ +/,$main);
	my($nick, $user, $host) = ($mask,"@",$mask);
	if($mask =~ /!/){
		($nick, $user, $host) = $mask =~ /^([^!]+)!([^@]+)@(.*)$/;
	}
	if($command eq "PRIVMSG"){
		if($longarg =~ s/^\x01ACTION (.*?)\x01?$/$1/){
			printf STDERR "%02d:%02d:%02d * %s:%s %s\n",(localtime)[2,1,0],$nick,$args[0],$longarg;
		}elsif($longarg =~ s/^\x01([^ \x01]+)(.*?)\x01?[\r\n]*$/$2/){
			printf STDERR "%02d:%02d:%02d CTCP %s from %s: %s\n",(localtime)[2,1,0],$1,$nick,$longarg;
			if($1 eq "PING"){
				$self->send("NOTICE $nick :\x01$1 $longarg\x01");
			}elsif($1 eq "TIME"){
				$self->send("NOTICE $nick :\x01$1 ".(localtime)."\x01");
			}elsif($1 eq "VERSION"){
				my $ver = "Artemis ";
				if($Artemis::VERSION){
					$ver .= "v$Artemis::VERSION";
				}elsif(-e './.bzr/branch/last-revision'){
					open REV, '<', './.bzr/branch/last-revision';
					my $rev = <REV>;
					chomp($rev);
					$ver .= "r$rev";
					close REV;
				}else{
					$ver .= "versionless trunk"
				}
				$self->send("NOTICE $nick :\x01$1 $ver\x01");
			}
			return;
		}else{
			printf STDERR "%02d:%02d:%02d <%s:%s> %s\n",(localtime)[2,1,0],$nick,$args[0],$longarg;
		}
		my $pm = lc($args[0]) eq lc($self->{nick});
		my $replyto = $pm ? $nick : $args[0];
		$self->{main}->incoming($self,Artemis::Message->new(user=>$nick,text=>$longarg,to=>$replyto,via=>$args[0],token=>"irc://".$self->{nick}."@".$self->{host}.":".$self->{port}."/#".$mask,nick=>$self->{nick}));
	}elsif($command eq "376" or $command eq "422"){
		$self->{onconnect}->($self);
	}elsif($command eq "NOTICE"){
		printf STDERR "%02d:%02d:%02d -%s- %s\n",(localtime)[2,1,0],$nick,$longarg;
	}elsif($command eq "JOIN"){
		printf STDERR "%02d:%02d:%02d -!- %s [%s] has joined %s\n",(localtime)[2,1,0],$nick,$mask,$longarg;
	}elsif($command eq "372" || $command eq "375"){
		push @{$self->{MOTD}}, sprintf "%02d:%02d:%02d %s\n",(localtime)[2,1,0],$longarg;
	}elsif($command eq "NICK"){
		if($nick eq $self->{nick}){
			$self->{nick} = $longarg;
			printf STDERR "%02d:%02d:%02d changed nicks to %s\n",(localtime)[2,1,0], $longarg;
		}else{
			my $frommask	=lc "irc://".$self->{nick}."@".$self->{host}.":".$self->{port}."/#".$mask;
			my $tomask	=lc "irc://".$self->{nick}."@".$self->{host}.":".$self->{port}."/#".$longarg."!".$user.'@'.$host;
			return unless exists $self->{main}{logins}{$frommask};
			$self->{main}{logins}{$tomask} = delete($self->{main}{logins}{$frommask});
		}
	}else{
		printf STDERR "%02d:%02d:%02d  ->%s\n",(localtime)[2,1,0],$data;
	#	print STDERR "++++ TODO: impliment '$command'\n";
	}
}
1;
