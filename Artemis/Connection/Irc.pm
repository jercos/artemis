package Artemis::Connection::Irc;
use IO::Socket;
sub new{
	my $class = shift;
	my $self = {
		host=>"localhost",	#server to connect to
		port=>"6667",		#port to connect on
		nick=>"artemis",	#nick!user@host, Real name: realname, if you don't get it, ignore these.
		user=>"artemis",
		realname=>"Artemis v2.0, Jeremy Sturdivant (jercos)",
		serverpass=>undef,	#if this is set, a PASS will be sent after USER and NICK. ignore this unless you want an IRCOP bot.
		nickpass=>undef,	#password to send to nickserv. leave it undef to not identify to nickserv
		autoconnect=>1,		#set to a false value to not immediately call $self->connect(), you'll have to call it later.
		onconnect=>sub{	#this will get called on an "end of MOTD" command from the server, or a "no MOTD" error.
			my $self = shift;
			$self->send("JOIN :$_") for @{$self->{autojoin}};
			$self->{main}->load($self,"Core");
		},
		sock=>undef,		#this holds an IO::Socket::INET object, or an IO::Handle, or similar. anything that works inside readline()
		autojoin=>[],		#what channels do we want to join automatically?
		modules=>{},		#this will contain Artemis::Plugin::* objects allowed to work with this connection.
					#preferably, each item will be copied from the master list of objects, but optionally one could call the constructor once for each connection
					#this would allow, for exmaple, a factoid module to keep seperate databases between different networks.
					#the format is Perl module name => object, e.g., $foo = Artemis::Plguin::fo->new();$self->{modules}{"Artemis::Plugin::foo"}=$foo
					#this prevents loading modules twice, and allows for easy unloading.
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
	$self->send("USER ".$self->{user}." - - :".$self->{realname},"NICK ".$self->{nick});
}
#we're done, y'all hear?
sub disconnect{
	my $self = shift;
	$self->{select}->remove($self->{sock});
	$self->send("QUIT :disconnect called :(\n");
	$self->{sock}->close();
}
#Process(0) for non-blocking, Process() for blocking, Process(0.25) to block for a quarter of a second. easy as pie.
#This will check select, and call the appropriate method. This should be called once every few seconds at least.
sub Process{
	my $self = shift;
	while(my $line = readline($self->{sock})){
		$self->irc($line);
	}
}
#a raw send, for exposing to the outside world, and shortening 
sub send{
	my $self = shift;
	return 0 unless defined $self->{sock};
	$self->debug(join("",map{"<- $_\n"}@_),0);
	print {$self->{sock}} join("",map{"$_\n"}@_); # this means $self->send("JOIN #foo","PRIVMSG #foo :howdy, everbody!") works as expected :P
}
#data headed outward to the network. this defines the scheme for extra data for Artemis::outgoing
sub outgoing{
	my $self = shift;
	my($msg, $replyto) = @_;
	$self->send("NOTICE $replyto :$_") for split(/[\r\n]+/,$msg);
}
#typing print STDOUT was getting boring.
sub debug{
	my $self = shift;
	my($msg,$level) = @_;
	print STDOUT $msg if $main::DEBUG>$level;
}
#this now does the actual parsing of incoming messages :)
sub irc{
	my $self = shift;
	my $data = shift;
	$data =~ s/[\r\n]//g;
	$self->debug(" ->$data\n",0);
	return $self->send($data) if $data =~ s/^PING/PONG/; 
	my($special,$main,$longarg) = split(/:/,$data,3);
	warn "---+ ".$self->{nick}." rcvd from ".$self->{host}.": '$special:$main:$longarg'" if $special;
	my($mask,$command,@args) = split(/ +/,$main);
	my($nick, $user, $host) = ($mask,"@",$mask);
	if($mask =~ /!/){
		($nick, $user, $host) = $mask =~ /^([^!]+)!([^@]+)@(.*)$/;
	}
	if($command eq "PRIVMSG"){
		my $replyto = ($args[0] eq $self->{nick} && $args[0] =~ /^[^#]/)?$nick:$args[0];
		$self->{main}->incoming($self,$nick,$longarg,"maybe",$replyto);
	}elsif($command eq "376" or $command eq "422"){
		$self->{onconnect}->($self);
	}else{
		$self->debug("++++ TODO: impliment '$command'\n",0);
	}
}
1;
