use strict;
use warnings;
use strict;
use Test::More;
use Capture::Tiny;

use Evert::E;
use Evert::Init;

# Wrong path test
eval
{

    $Evert::Init::PATH = 'no_file';
    $Evert::Init::ST_EVENT = 0;

    is($Evert::Init::PATH, 'no_file', 'Path set');
    Evert::Init::init();
};

like($@, qr/no_file does not exist/, 'Wrong path test');

# Wrong config file structure
eval
{
    $Evert::Init::PATH = 't/wrong_json_file.json';
    Evert::Init::init();
};
like($@, qr/Error found in config file/, 'Wrong config file structure');

# No event section test
eval
{
    $Evert::Init::PATH = 't/wrong_events_section.json';
    Evert::Init::init();
};
like($@, qr/No config section in /, 'No event section test');

# Other config path
eval
{
    $Evert::Init::PATH = 't/empty_config.json';
    Evert::Init::init();
};
is($@, '', 'Change config path');

# _gl test
my $stderr =  Capture::Tiny::capture_stderr
    {
        eval
        {
            Evert::Init::_gl(undef, 'Test logs 1');
        }
    };

like($stderr , qr/VAR1 = 'Test logs 1'/, 'Test logs');

# _error_log test plain text
$stderr =  Capture::Tiny::capture_stderr
{
    Evert::Init::_error_log(undef, 'Test logs 2');
};

like($stderr , qr/VAR1 = 'Critical error\tTest logs 2'/, 'Test logs with plain text');

# _error_log test hash test
$stderr =  Capture::Tiny::capture_stderr
{
    my ($package, $filename, $line) = caller;
    Evert::Init::_error_log(undef, {handler => {line => $line, filename=>$filename, package => $package}, name => 'Name test', error => 'Test logs'});
};

like($stderr , qr/Critical error\tIn Name test, file.*Tiny.pm, package Capture::Tiny/, 'Test logs with hash');

# Standant event off
is (Evert::E::has_action('evert_logs'), 0, 'Standart event - test 1');
is (Evert::E::has_action('evert_error'), 0, 'Standart event - test 2');

# Standant event
$Evert::Init::ST_EVENT = 1;
$Evert::Init::PATH = 't/wrong_package_event.json';
Evert::Init::init();
is (Evert::E::has_action('evert_logs'), 1, 'Standart event - test 4');
is (Evert::E::has_action('evert_error'), 1, 'Standart event - test 5');

# evert_logs - STDERR
$stderr =  Capture::Tiny::capture_stderr
{
    Evert::E::do_action('evert_logs', 'Test logs 3');
};
like($stderr , qr/VAR1 = 'Test logs 3'/, 'evert_logs event with STDERR');

# evert_error - STDERR
$stderr =  Capture::Tiny::capture_stderr
    {
        Evert::E::do_action('evert_error', 'Test logs 4');
    };
like($stderr , qr/VAR1 = 'Critical error\tTest logs 4'/, 'evert_error event with STDERR');

# evert_logs - file
$Evert::Init::LOG_FILE = 't/log.txt';
Evert::E::do_action('evert_logs', 'Test logs 5');
my $text=read_log();
like($text , qr/VAR1 = 'Test logs 5'/, 'evert_logs event with STDERR');
unlink('t/log.txt');

# evert_error - file
Evert::E::do_action('evert_error', 'Test logs 6');
$text=read_log();
like($text , qr/VAR1 = 'Critical error\tTest logs 6'/, 'evert_error event with STDERR');
unlink('t/log.txt');

# _postponed_event wrong package use
Evert::E::do_action('wrong_event');
$text=read_log();
like($text , qr/Critical error\tt\/WrongPackage.pm did not return a true value at/, 'Wrong package use test');
unlink('t/log.txt');
Evert::E::remove_action('wrong_event');

# _postponed_event wrong sub inside package
$Evert::Init::PATH = 't/wrong_event_sub.json';
Evert::Init::init();
Evert::E::do_action('wrong_event');
$text=read_log();
like($text , qr/Throw exception at t\/WrongSub\.pm/, 'Wrong sub test');
unlink('t/log.txt');
Evert::E::remove_action('wrong_event');

# good events
$Evert::Init::PATH = 't/good_config.json';
Evert::Init::init();
is (Evert::E::has_action('filter_1'), 1, 'Good event - 1');
is (Evert::E::has_action('action_1'), 1, 'Good event - 2');
is (Evert::E::apply_filter('filter_1', '_ok'), 'This is action_first_ok', 'Good event - 3');
is (Evert::E::apply_filter('action_1'), 'This is action_second', 'Good event - 4');

done_testing();

sub read_log
{
    open (my $file, '<t/log.txt');
    my $t = join '', reverse <$file>;
    close ($file);
    return $t;
}