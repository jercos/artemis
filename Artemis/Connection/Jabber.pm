package Artemis::Connection::Jabber;
use Net::Jabber;
use strict;
sub new{
	my $class = shift;
	my $self = {
		sock=>Net::Jabber::Client->new,
		user=>"artemis",
		host=>"jercos.dyndns.org",
		pass=>"",
		modules=>{},
		autoconnect=>1,
		resource=>"artemis2",
		presence=>time,
		@_
	};
	bless($self,$class);
	$self->{main}->load($self,"Core");
	$self->connect() if $self->{autoconnect};
	return $self;
}

sub connect{
	my $self = shift;
	$self->{sock}->Connect(hostname=>$self->{host});
	my @result = $self->{sock}->AuthSend(username=>$self->{user},password=>$self->{pass},resource=>$self->{resource});
	$self->{sock}->PresenceSend();
	$self->{sock}->SetCallBacks(message => sub{$self->jabber(@_)});
	print "Jabber connection returned '".join("','",@result)."'\n";
}

sub disconnect{
	my $self = shift;
	$self->{sock}->Disconnect();
}

sub Process{
	my $self = shift;
	$self->{sock}->PresenceSend() if time - $self->{presence} > 60;
	$self->{sock}->Process(0);
}

sub send{
	return "sorry, Artemis::Connection::Jabber does not support send. please use message instead.";
}

sub message{
	my $self = shift;
	my($replyto,$msg)=@_;
	#$self->{sock}->Send($replyto->Reply($msg));
	$self->{sock}->MessageSend(to=>$replyto,body=>$msg);
	print "jabber://$replyto <- $msg\n"
}

sub jabber{
	my $self = shift;
	my $msg = pop;
	return unless $msg->DefinedBody();
        my $input = $msg->GetBody();
        my $from = $msg->GetFrom();
	$from =~ /^(.*)@/;
	my $nick = $1;
	$input =~ s/[\r\n]//g;
	return unless $input;
	print "jabber://$from -> $input\n";
	$self->{main}->incoming($self,$nick,$input,1,$from,"jabber://".$self->{user}.'@'.$self->{host}."/".$self->{resource}."#$from");
}
1;
