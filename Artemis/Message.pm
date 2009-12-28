package Artemis::Message;
sub new{
	my $class = shift;
	my $self = {
		text=>undef,	# the content of the message
		to=>undef,	# how do i get back to the person who sent me this? Connection module specific...
		via=>undef,	#! who the message was sent to. for IRC this can be a channel or my nick.
		user=>undef,	#! username for the user who sent this, or or a nickname for the recipient.
		pm=>0,		# was this a private message, or part of a channel?
		level=>undef,	# what level was the user who sent this? undef for not logged in.
		token=>"null://",	# authentication string to be matched against the auth database.
#TODO: make null:// magical.
		nick=>"artemis",	# her nickname in the context of the message.
		@_
	};
	if($self->{text}=~s/^\)|^($self->{nick})[, :]+// || $self->{via} eq $self->{nick}){
		$self->{pm}=1;
	}
	return bless($self, $class);
}
sub text{
	my $self = shift;
	if(@_){$self->{text}=shift;return $self}
	return $self->{text};
}
sub to{
	my $self = shift;
	if(@_){$self->{to}=shift;return $self}
	return $self->{to};
}
sub via{
	return shift->{via};
}
sub user{
	my $self = shift;
	return $self->{user} || $self->{to};
}
sub level{
	return shift->{level};
}
sub token{
	return shift->{token};
}
sub pm{
	my $self = shift;
	if(@_){$self->{pm}=!(!shift);return $self}
	return $self->{pm};
}
sub auth{
	my $self = shift;
	($self->{user},$self->{level})=@_;
	return $self;
}
1;
