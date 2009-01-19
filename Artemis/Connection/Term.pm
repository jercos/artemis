package Artemis::Connection::Term;
use Term::ReadKey;
sub new{
	my $class = shift;
	my $self = {
		sock=>undef,
		nick=>"artemis",
		modules=>{},
		@_
	};
	bless($self,$class);
	$self->{main}->load($self,"Core");
	return $self;
}

sub connect{
	my $self = shift;
	print "Connecting\n";
	return unless defined($self->{sock});
}

sub disconnect{
	my $self = shift;
	return unless defined($self->{sock});
}

sub Process{
	my $self = shift;
	my $input;
	if(defined $self->{sock}){
		$input = ReadLine(-1,$self->{sock});
	}else{
		$input = ReadLine(-1);
	}
	return unless $input;
	$self->{main}->incoming($self,"cons",$input,1,"cons","term://");
	print "sent '$input'\n";
}

sub send{
	my $self = shift;
	print "$_\n" for @_;
}

sub message{
	my $self = shift;
	my($replyto,$msg)=@_;
	$self->send("$replyto: $msg");
}

sub term{

}
1;
