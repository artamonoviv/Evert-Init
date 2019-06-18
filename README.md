# NAME

Evert::Init -  a subsystem for postpone load of modules until their events are used.

# VERSION

version 0.003

# SYNOPSIS

    use Evert::E;

    use Evert:Init;

    Evert::Init::init(); # read a list of events and their packages from config.json

    Evert::E::do_action('name_of_event_1'); # connect to a 'name_of_event_1' package, execute 'name_of_event_1'.

# DESCRIPTION

Evert::Init works like autouse.pm but for Evert's events. It allows to defer module loading until its event is actually needed.

A list of all events needed to deferred loading are stored in json file (config.json by default). A function Evert::Init::init() reads the config file and registers found events in Evert::E with a handler pointed to Evert::Init.
When an event is called the first time, Evert::Init requires a corresponding module, imports its strings, registers the right event's handler and then calls the event.

Evert::Init is very useful if you have tens and hundreds of modules to load when only a few are really used and a list of needed modules is dependent on outside factors and is changed each program run.

Evert::Init is not your choice if you have few modules or need to use all of their permanently.

Additionally Evert::Init registers own handlers for two auxiliary events: 'evert\_log' and 'evert\_error'.

# METHODS

## init()

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
A complex way need an array of hashes. Each hash must have 'name':'full path' pair and can have 'priority', 'async', 'async\_callback, 'is\_alone' keys. See Evert::E::add\_action() for details.

The name of the config file can be changed with $Evert::Init::PATH variable before init() call.

    $Evert::Init::PATH = 'config/some_file.json';
    Evert::Init::init();

## 'evert\_log' and 'evert\_error' events

By default Evert::Init adds two handlers for events 'evert\_log' and 'evert\_error'.

Each handler prints a message to STDERR. You can specify a file as log output:

        $Evert::Init::LOG_FILE = 'logs/evert_log.txt';
        Evert::E::do_action('evert_logs', 'Test');

The 'evert\_error' is used to signalize about critical and fatal errors. Its message always starts from the text 'Critical error'.

You can pass text or hashref as a filter content. In case of plain text Evert::Init prints 'Critical error\\tYour text' as a message.
In case of hashref a message will be 'Critical error\\tIn $hashref->{name}, file $hashref->{filename}, package $hashref->{package}, line $hashref->{line}: $hashref->{error}'.

The 'evert\_log' is used for logging. A content parameter of the filter can be any type because of using Data::Dumper::Dumper($content) for output.

        Evert::E::do_action('evert_logs', 'Test'); # OK
        Evert::E::do_action('evert_logs', $hashref); # OK
        Evert::E::do_action('evert_logs', $arrayref); # OK

A output message has folowing structure: '$mday.$mon.$year $hour:$min:$sec\\tEvert\\t$package|$file|$line\\t'.Dumper($text).'\\n';

You can switch off these event registering with $Evert::Init::ST\_EVENT = 0 flag before init();

# INSTALLATION

You can install Evert::Init by command: cpanm https://github.com/artamonoviv/Evert-Init/tarball/master

# AUTHOR

Ivan Artamonov, &lt;ivan.s.artamonov {at} gmail.com>

# LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
