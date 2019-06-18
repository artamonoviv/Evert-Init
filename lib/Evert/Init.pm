package Evert::Init;
use utf8;
use strict;
use warnings;
use JSON::MaybeXS ();
use Carp ();
use Evert::E ();

our $VERSION = '0.002';

our $PATH="config/config.json";
our $ST_EVENT=1;
our $LOG_FILE=undef;

my %postponed_events; #local cache

sub init
{

	Carp::croak "$PATH does not exist" if (!-e $PATH);

	open(my $file, "< :utf8", $PATH);

	my $text=(join '', <$file>);

	Carp::croak "No data in $PATH" if (!length($text));

	my $config = {};

	eval
	{
		$config = JSON::MaybeXS::decode_json( $text );
	};

	if ($@)
	{
		Carp::croak "Error found in config file: $@";
	}

	close ($file);

	if (exists($config->{events}))
	{
		foreach my $event(keys %{$config->{events}})
		{
			if(ref($config->{events}->{$event}) eq "ARRAY")
			{
				foreach my $sub (reverse @{$config->{events}->{$event}})
				{
					my $priority=(exists($sub->{priority}) ? $sub->{priority} : 1);
					my $async=(exists($sub->{async}) ? $sub->{async} : 0);
					my $async_callback=(exists($sub->{async_callback}) ? $sub->{async_callback} : undef);
					my $is_alone=(exists($sub->{is_alone}) ? $sub->{is_alone} : 0);

					my $n=Evert::E::add_action($event,\&_postponed_event,{priority=>$priority, async=>$async, is_alone=>$is_alone});
					push @{$postponed_events{$event}}, {sub=>$sub->{name},id_event=>$n,priority=>$priority, async=>$async, async_callback=>$async_callback, is_alone=>$is_alone};
				}
			}
			else
			{
				my $n=Evert::E::add_action($event,\&_postponed_event);
				push @{$postponed_events{$event}}, {sub=>$config->{events}->{$event},id_event=>$n,priority=>1};
			}
		}
	}
	else
	{
		Carp::croak "No config section in $PATH";
	}
	
	if ($ST_EVENT)
	{
		Evert::E::add_action("evert_error",\&_error_log, {priority=>1})if (!Evert::E::has_action("evert_error"));
		Evert::E::add_action("evert_logs",\&_gl, {priority=>1})if (!Evert::E::has_action("evert_logs"));
	}
}

sub _error_log
{
	my ($action, $info)=@_;

	my $text;
	my $name = '';

	if (ref($info) eq "HASH")
	{
		$name=$info->{name};
		my $handler=$info->{handler};
		my $error=$info->{error};
		$text = "Critical error\tIn $name, file $handler->{filename}, package $handler->{package}, line $handler->{line}: $error";
	}
	else
	{
		$text = "Critical error\t".$info;
	}

	eval
	{
		if($name eq "evert_logs" || !Evert::E::do_action("evert_logs", $text))
		{
			_gl(undef,$text);
		}
	};

	if($@)
	{
		_gl(undef,$text);
	}
}


sub _gl
{
	use autouse "Data::Dumper"=>qw(Dumper);

	my ($sec,$min,$hour,$mday,$mon,$year) = (localtime(time))[0..5];
	$year+=1900;
	$mon++;

	my $text=$_[1];

	my $log;

	open($log, ">> :utf8",  $LOG_FILE) if($LOG_FILE);

	my ($package,$file,$line)=caller;

	if($LOG_FILE)
	{

		if (flock($log, 2))
		{
			print $log "$mday.$mon.$year $hour:$min:$sec\tEvert\t$package|$file|$line\t".Dumper($text)."\n";
			flock($log, 8);
		}
	}
	else
	{
		print STDERR "$mday.$mon.$year $hour:$min:$sec\tEvert\t$package|$file|$line\t".Dumper($text)."\n";
	}
	close($log) if($LOG_FILE);

	return 1;
}

no strict 'refs';

sub _postponed_event
{
	my $action=$_[0];
	if(exists($postponed_events{$action->{name}}))
	{
		foreach my $elem (sort {$a->{priority} <=> $b->{priority}} @{$postponed_events{$action->{name}}})
		{
			my $sub=_prepare_sub($elem->{sub}, $action);

			my $async_callback=sub {};

			if ($elem->{async_callback} && index($elem->{async_callback},'::') != -1)
			{
				$async_callback=_prepare_sub($elem->{async_callback}, $action);
			}

			if (!Evert::E::remove_action($action->{name}, {id=>$elem->{id_event}}))
			{
				if ($action ne 'evert_error')
				{
					Evert::E::do_action("evert_error", "An error happened while removing postponed event");
				}
				else
				{
					_gl(undef, "An error happened when removing postponed event");
				}
			}

			Evert::E::add_action($action->{name}, \&$sub, {priority=>$elem->{priority}, async=>$elem->{async}, async_callback=>$async_callback, is_alone=>$elem->{is_alone}});
		}

		delete($postponed_events{$action->{name}});

		return Evert::E::apply_filter($action->{name},  @_[1 .. $#_]);
	}
	return $_[1];
}

sub _prepare_sub
{
	my $sub=$_[0];
	my $action=$_[1];
	my $func = substr($sub, rindex($sub, '::') + 2, length($sub));
	my $package = substr($sub, 0, rindex($sub, '::'));
	(my $pm = $package) =~ s{::}{/}g;
	$pm .= '.pm';

	if (!exists($INC{$pm}))
	{
		eval
		{
			require $pm;
			$pm->import($func);
		};
		if ($@)
		{

			if ($action ne 'evert_error')
			{
				Evert::E::do_action("evert_error", $@);
			}
			else
			{
				_gl(undef,$@);
			}
		}
	}

	*$sub = \&{$package."::$func"};

	return $sub;
}

=pod

=encoding UTF-8

=head1 NAME

Evert::Init -  a subsystem for postpone load of modules until their events are used.

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use Evert::E;

    use Evert:Init;

    Evert::Init::init(); # read a list of events and their packages from config.json

    Evert::E::do_action('name_of_event_1'); # connect to a 'name_of_event_1' package, execute 'name_of_event_1'.


=head1 DESCRIPTION

Evert::Init works like autouse.pm but for Evert's events. It allows to defer module loading until its event is actually needed.

A list of all events needed to deferred loading are stored in json file (config.json by default). A function Evert::Init::init() reads the config file and registers found events in Evert::E with a handler pointed to Evert::Init.
When an event is called the first time, Evert::Init requires a corresponding module, imports its strings, registers the right event's handler and then calls the event.

Evert::Init is very useful if you have tens and hundreds of modules to load when only a few are really used and a list of needed modules is dependent on outside factors and is changed each program run.

Evert::Init is not your choice if you have few modules or need to use all of their permanently.

Additionally Evert::Init registers own handlers for two auxiliary events: 'evert_log' and 'evert_error'.

=head1 METHODS

=head2 init()

Read a list of events and their packages from config.json, registers found events in Evert::E.

A structure of config.json must be like this:

	{
		"events":
		{
			"name_of_event_1_complex_way" :
			[
				{"name":"FirstPackage::action_first", "priority":2, "async":1, "async_callback": "FirstPackage::action_callback", "is_alone":0 },
				{"name":"FirstPackage::action_first", "priority":5}
			],
			"name_of_event_2_simple_way" : "SecondPackage::action_second"
		}
	}

There are two ways to describe an event.
A simple way requires a name of the event and a full path to a handler.
A complex way need an array of hashes. Each hash must have 'name':'full path' pair and can have 'priority', 'async', 'async_callback, 'is_alone' keys. See Evert::E::add_action() for details.

The name of the config file can be changed with $Evert::Init::PATH variable before init() call.

    $Evert::Init::PATH = 'config/some_file.json';
    Evert::Init::init();

=head2 'evert_log' and 'evert_error' events

By default Evert::Init adds two handlers for events 'evert_log' and 'evert_error'.

Each handler prints a message to STDERR. You can specify a file as log output:

	$Evert::Init::LOG_FILE = 'logs/evert_log.txt';
	Evert::E::do_action('evert_logs', 'Test');

The 'evert_error' is used to signalize about critical and fatal errors. Its message always starts from the text 'Critical error'.

You can pass text or hashref as a filter content. In case of plain text Evert::Init prints 'Critical error\tYour text' as a message.
In case of hashref a message will be 'Critical error\tIn $hashref->{name}, file $hashref->{filename}, package $hashref->{package}, line $hashref->{line}: $hashref->{error}'.

The 'evert_log' is used for logging. A content parameter of the filter can be any type because of using Data::Dumper::Dumper($content) for output.

	Evert::E::do_action('evert_logs', 'Test'); # OK
	Evert::E::do_action('evert_logs', $hashref); # OK
	Evert::E::do_action('evert_logs', $arrayref); # OK

A output message has folowing structure: '$mday.$mon.$year $hour:$min:$sec\tEvert\t$package|$file|$line\t'.Dumper($text).'\n';

You can switch off these event registering with $Evert::Init::ST_EVENT = 0 flag before init();

=head1 INSTALLATION

You can install Evert::Init by command: cpanm https://github.com/artamonoviv/Evert-Init/tarball/master

=head1 AUTHOR

Ivan Artamonov, <ivan.s.artamonov {at} gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut

1;