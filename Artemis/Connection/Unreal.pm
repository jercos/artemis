package Artemis::Connection::Unreal;
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
		hostname=>"omg.irc.wtf.bbq",
		mode=>"+NS",		#user modes for her token user.
		pass=>undef,		#set this to the password for the link
		info=>"ArtyServ!",	#server information
		name=>"irc.services",	#the name for our server.
		autoconnect=>1,		#set to a false value to not immediately call $self->connect(), you'll have to call it later.
		sock=>undef,		#this holds an IO::Socket::INET object, or an IO::Handle, or similar. anything that works inside readline()
		autojoin=>[],		#what channels do we want to join automatically?
		sident=>"services",	#username for services modules
		shost=>"example.net",	#hostname for services modules
		services=>{},		#hash of nick => real name.
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
	$self->send(
		"PASS :".$self->{pass},
		"SERVER ".$self->{name}." 1 :".$self->{info},
	);
	$self->spawn();
}
#This will spawn up a copy of Arty, colliding any old ones out of the way. Great for when an inept Oper KILLs her.
sub spawn{
	my $self = shift;
	my $skipself = shift || 0;
	my($nick,$user,$hostname,$name,$realname,$autojoin,$mode,$sident,$shost) = @{$self}{qw(nick user hostname name realname autojoin mode sident shost)};
	$self->send(
		"NICK $nick 1 ".time." $user $hostname $name 0 $mode $hostname :$realname",
		":$nick JOIN ".join(",",@$autojoin),
	) unless $skipself;
	for my $service (keys %{$self->{services}}){
		my $rname = $self->{services}{$service};
		$self->send("NICK $service 1 ".time." $sident $shost $name 0 $mode $shost :$rname");
	}
}
#we're done, y'all hear?
sub disconnect{
	my $self = shift;
	$self->send("SQUIT");
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
	return 0 unless defined $self->{sock};
	for(@_){
		my $x = "$_";
		$x =~ s/[\r\n]/\\n/g;
		printf STDERR "%02d:%02d:%02d  <-%s\n" ,(localtime)[2,1,0] ,$x;
		print {$self->{sock}} "$x\n";
	}
}
#data headed outward to the network. this defines the scheme for extra data for Artemis::outgoing
sub message{
	my $self = shift;
	my($replyto, $msg, $from) = @_;
	$from ||= $self->{nick};
	for(split(/[\r\n]+/,$msg)){
		printf STDERR "%02d:%02d:%02d <%s:%s> %s\n" ,(localtime)[2,1,0],$from ,$replyto ,$_;
		print {$self->{sock}} ":$from PRIVMSG $replyto :$_\n";
	}
}
#this now does the actual parsing of incoming messages :)
sub irc{
	my $self = shift;
	my $data = shift;
	$data =~ s/[\r\n]//g;
	my($special,$main,$longarg) = split(/:/,$data,3);
	return $self->send($data) if $data =~ s/^PING/PONG/;
	return $self->{sock}->close() if $data =~ /^ERROR/;
	my($mask,$command,@args) = split(/ +/,$main);
	if($command eq "PRIVMSG"){
		if($longarg =~ s/^\x01ACTION (.*?)\x01?$/$1/){
			printf STDERR "%02d:%02d:%02d * %s:%s %s\n",(localtime)[2,1,0],$mask,$args[0],$longarg;
		}elsif($longarg =~ s/^\x01([^ \x01]+)(.*?)\x01?[\r\n]*$/$2/){
			my $nick = $self->{nick};
			printf STDERR "%02d:%02d:%02d CTCP %s from %s: %s\n",(localtime)[2,1,0],$1,$mask,$longarg;
			if($1 eq "PING"){
				$self->send(":$nick NOTICE $mask :\x01$1 $longarg\x01");
			}elsif($1 eq "TIME"){
				print "Got a TIME.\n";
				$self->send(":$nick NOTICE $mask :\x01$1 ".(localtime)."\x01");
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
				$self->send(":$nick NOTICE $mask :\x01$1 $ver\x01");
			}
			return;
		}else{
			printf STDERR "%02d:%02d:%02d <%s:%s> %s\n",(localtime)[2,1,0],$mask,$args[0],$longarg;
		}
		my $pm = lc($args[0]) eq lc($self->{nick});
		my $replyto = $pm ? $mask : $args[0];
		$replyto = $mask if $args[0] =~ /^[a-z]+$/;
		$self->{main}->incoming($self,Artemis::Message->new(user=>$mask,text=>$longarg,to=>$replyto,via=>$args[0],token=>"unreal://".$self->{name}."/".$mask,nick=>$self->{nick}));
	}elsif($command eq "NOTICE"){
		printf STDERR "%02d:%02d:%02d -%s- %s\n",(localtime)[2,1,0],$mask,$longarg;
	}elsif($command eq "JOIN"){
		printf STDERR "%02d:%02d:%02d -!- %s has joined %s\n",(localtime)[2,1,0],$mask,$args[0];
	}elsif($command eq "NICK"){
		if($mask eq $self->{nick}){
			$self->{nick} = $longarg;
			printf STDERR "%02d:%02d:%02d changed nicks to %s\n",(localtime)[2,1,0], $longarg;
		}else{
			my $frommask	=lc "unreal://".$self->{name}."/".$mask;
			my $tomask	=lc "unreal://".$self->{name}."/".$args[0];
			return unless exists $self->{main}{logins}{$frommask};
			$self->{main}{logins}{$tomask} = delete($self->{main}{logins}{$frommask});
		}
	}elsif($command eq "QUIT"){
		my $token=lc "unreal://".$self->{name}."/".$mask;
		if(exists $self->{main}{logins}{$token}){
			delete $self->{main}{logins}{$token};
			printf STDERR "%02d:%02d:%02d -!- Logging out %s due to quit...\n",(localtime)[2,1,0],$mask;
		}
		printf STDERR "%02d:%02d:%02d -!- %s has quit (%s)\n",(localtime)[2,1,0],$mask,$longarg;
	}else{
		printf STDERR "%02d:%02d:%02d  ->%s\n",(localtime)[2,1,0],$data;
	#	print STDERR "++++ TODO: impliment '$command'\n";
	}
}
1;
