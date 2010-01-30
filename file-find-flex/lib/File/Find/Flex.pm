package File::Find::Flex;

# ABSTRACT: Flexible file finding.

use Moose;
use Moose::Util::TypeConstraints;
use Moose::Meta::TypeConstraint;
use MooseX::StrictConstructor;
use File::Util;
use Text::Glob 'glob_to_regex';
use Number::Compare;
use Number::Compare::Date;

#file size subtype with Number::Compare semantics
subtype 'Size'
    => as 'Str'
    => where { $_ =~ m/^(>=|>|<=|<){0,1}\d+(k|ki|m|mi|g|gi){0,1}$/i };

#date subtype with Number::Compare::Date semantics
subtype 'Date'
    => as 'Str';

#available test directives    
enum 'Directive' => qw(readable r_readable writable r_writable
                        executable r_executable owned r_owned
                        exists file empty directory
                        nonempty symlink fifo setuid
                        socket setgid block sticky
                        character tty modified accessed
                        ascii changed binary);

#file permissions subtype                        
subtype 'Perms'
    => as 'Str'
    => where { $_ =~ m/^([r-][w-][x-]){3}$/ };

#file bitmask subtype    
subtype 'Bitmask'
    => as 'Str'
    => where { $_ =~ m/^[1-7]{3}$/ };

#what the file names should look like
has 'like' => (
    is => 'rw',
    isa => 'Str|RegexpRef|ArrayRef[Str|RegexpRef]|Undef',
    predicate => 'has_like',
    reader => '_get_like',
    writer => '_set_like',
);

#what they shouldn't look like
has 'unlike' => (
    is => 'rw',
    isa => 'Str|RegexpRef|ArrayRef[Str|RegexpRef]|Undef',
    predicate => 'has_unlike',
    reader => '_get_unlike',
    writer => '_set_unlike',
);

#acceptable file extensions
has 'ext' => (
    is => 'rw',
    isa => 'Str|ArrayRef[Str]',
    predicate => 'has_ext',
    reader => '_get_ext',
    writer => '_set_ext',
);

#subs that should take one argument and return
#true or false if the file is 'good' or 'bad'
has 'subs' => (
    is => 'rw',
    isa => 'CodeRef|ArrayRef[CodeRef]',
    predicate => 'has_subs',
    reader => '_get_subs',
    writer => '_set_subs',
);

#directories to look in
has 'dirs' => (
    is => 'rw',
    isa => 'Str|ArrayRef[Str]',
    predicate => 'has_dirs',
    reader => '_get_dirs',
    writer => '_set_dirs',
);

#acceptable file sizes, using Number::Compare semantics
has 'size' => (
    is => 'rw',
    isa => 'Size|ArrayRef[Size]',
    predicate => 'has_size',
    reader => '_get_size',
    writer => '_set_size',
);

#created date/time using Number::Compare::Date
has 'changed' => (
    is => 'rw',
    isa => 'Date|ArrayRef[Date]',
    predicate => 'has_changed',
    reader => '_get_changed',
    writer => '_set_changed',
);

#modified date/time using Number::Compare::Date/Number::Compare::Duration
has 'modified' => (
    is => 'rw',
    isa => 'Date|ArrayRef[Date]',
    predicate => 'has_modified',
    reader => '_get_modified',
    writer => '_set_modified',
);

#accessed date/time using Number::Compare::Date/Number::Compare::Duration
has 'accessed' => (
    is => 'rw',
    isa => 'Date|ArrayRef[Date]',
    predicate => 'has_accessed',
    reader => '_get_accessed',
    writer => '_set_accessed',
);

#recursively process subdirectories?
has 'recurse' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

#filetest directives the file should be like
has 'is' => (
    is => 'rw',
    isa => 'Directive|ArrayRef[Directive]',
    predicate => 'has_is',
    reader => '_get_is',
    writer => '_set_is',
);

#filetest directives the file shouldn't be like
has 'isnt' => (
    is => 'rw',
    isa => 'Directive|ArrayRef[Directive]',
    predicate => 'has_isnt',
    reader => '_get_isnt',
    writer => '_set_isnt',
);

#file owner(s)
has 'owner' => (
    is => 'rw',
    isa => 'Str|ArrayRef[Str]',
    predicate => 'has_owner',
    reader => '_get_owner',
    writer => '_set_owner',
);

#file group(s)
has 'group' => (
    is => 'rw',
    isa => 'Str|ArrayRef[Str]',
    predicate => 'has_group',
    reader => '_get_group',
    writer => '_set_group',
);

#file permissions
has 'perms' => (
    is => 'rw',
    isa => 'Perms|Bitmask|ArrayRef[Perms|Bitmask]',
    predicate => 'has_perms',
    reader => '_get_perms',
    writer => '_set_perms',
);

#where to hold our files before we return them
has 'files' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    writer => '_set_files',
    default => sub { [] },
);

sub BUILD {
    my $self = shift;
    
    #like
    if($self->has_like()) {
        $self->like($self->like());
    }
    
    #unlike
    if($self->has_unlike()) {
        $self->unlike($self->unlike());
    }
    
    #dirs
    if($self->has_dirs()) {
        $self->dirs($self->dirs());
    }
    
    #exts
    if($self->has_ext()) {
        $self->ext($self->ext());
    }
    
    #subs
    if($self->has_subs()) {
        $self->subs($self->subs());
    }
    
    #size
    if($self->has_size()) {
        $self->size($self->size());
    }
    
    #changed
    if($self->has_changed()) {
        $self->changed($self->changed());
    }
    
    #modified
    if($self->has_modified()) {
        $self->modified($self->modified());
    }
    
    #accessed
    if($self->has_accessed()) {
        $self->accessed($self->accessed());
    }
    
    #is
    if($self->has_is()) {
        $self->is($self->is());
    }
    
    #isnt
    if($self->has_isnt()) {
        $self->isnt($self->isnt());
    }
        
    #owner
    if($self->has_owner()) {
        $self->owner($self->owner());
    }
    
    #group
    if($self->has_group()) {
        $self->group($self->group());
    }
    
    #perms
    if($self->has_perms()) {
        $self->perms($self->perms());
    }
}

sub dirs {
    my $self = shift;
    my $dirs = shift;
    
    if(!defined($dirs)) {
        return $self->_get_dirs();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($dirs)) {
        return $self->_set_dirs([$dirs]);
    } else { 
        return $self->_set_dirs($dirs);
    }
}

sub ext {
    my $self = shift;
    my $ext = shift;
    
    if(!defined($ext)) {
        return $self->_get_ext();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($ext)) {
        return $self->_set_ext([$ext]);
    } else {
        return $self->_set_ext($ext);
    }
}

sub subs {
    my $self = shift;
    my $subs = shift;
    
    if(!defined($subs)) {
        return $self->_get_subs();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('CodeRef')->check($subs)) {
        return $self->_set_subs([$subs]);
    } else {
        return $self->_set_subs($subs);
    }
}

sub size {
    my $self = shift;
    my $size = shift;
    
    if(!defined($size)) {
        return $self->_get_size();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Size')->check($size)) {
        return $self->_set_size([$size]);
    } else {
        return $self->_set_size($size);
    }
}

sub changed {
    my $self = shift;
    my $changed = shift;

    if(!defined($changed)) {
        return $self->_get_changed();
    }

    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Date')->check($changed)) {
        return $self->_set_changed([$changed]);
    } else {
        return $self->_set_changed($changed);
    }
}

sub modified {
    my $self = shift;
    my $modified = shift;

    if(!defined($modified)) {
        return $self->_get_modified();
    }

    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Date')->check($modified)) {
        return $self->_set_modified([$modified]);
    } else {
        return $self->_set_modified($modified);
    }
}

sub accessed {
    my $self = shift;
    my $accessed = shift;

    if(!defined($accessed)) {
        return $self->_get_accessed();
    }

    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Date')->check($accessed)) {
        return $self->_set_accessed([$accessed]);
    } else {
        return $self->_set_accessed($accessed);
    }
}

sub is {
    my $self = shift;
    my $is = shift;
    
    if(!defined($is)) {
        return $self->_get_is();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Directive')->check($is)) {
        $self->_set_is([$is]);
    } else {
        return $self->_set_is($is);
    }
}

sub isnt {
    my $self = shift;
    my $isnt = shift;
    
    if(!defined($isnt)) {
        return $self->_get_isnt();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Directive')->check($isnt)) {
        $self->_set_isnt([$isnt]);
    } else {
        return $self->_set_isnt($isnt);
    }
}

sub owner {
    my $self = shift;
    my $owner = shift;
    
    if (!defined($owner)) {
        return $self->_get_owner();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($owner)) {
        return $self->_set_owner([$owner]);
    } else {
        return $self->_set_owner($owner);
    }
}

sub group {
    my $self = shift;
    my $group = shift;
    
    if (!defined($group)) {
        return $self->_get_group();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($group)) {
        return $self->_set_group([$group]);
    } else {
        return $self->_set_group($group);
    }
}

sub perms {
    my $self = shift;
    my $perms = shift;
    
    if(!defined($perms)) {
        return $self->_get_perms();
    }
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Perms')->check($perms)
    || Moose::Util::TypeConstraints::find_or_parse_type_constraint('Bitmask')->check($perms)) {
        return $self->_set_perms([$perms]);
    } else {
        return $self->_set_perms($perms);
    }
}

sub like {
    my $self = shift;
    my $like = shift;
    
    if(!defined($like)) {
        return $self->_get_like();
    }
    
    return $self->_set_like(_like_processor($like));
}

sub unlike {
    my $self = shift;
    my $unlike = shift;
    
    if(!defined($unlike)) {
        return $self->_get_unlike();
    }
    
    return $self->_set_unlike(_like_processor($unlike));
}

sub _like_processor {
    my ($like) = @_;
    
    if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($like)) {
        #convert to regex, and put in a one-element arrayref
        $like = [glob_to_regex($like)];
    } elsif(Moose::Util::TypeConstraints::find_or_parse_type_constraint('RegexpRef')->check($like)) {
        #convert to a one-element arrayref
       $like = [$like];
    } elsif(Moose::Util::TypeConstraints::find_or_parse_type_constraint('ArrayRef')->check($like)) {
        #check each element in the array ref, and make them all regexen
        for(my $i = 0; $i <= $#{$like}; ++$i) {
            if(Moose::Util::TypeConstraints::find_or_parse_type_constraint('Str')->check($like->[$i])) {
                $like->[$i] = glob_to_regex($like->[$i]);
            }
        }
    } else {
        #should never happen
        Carp::croak("Invalid type encountered for an element of like with value $like");
    }
    
    return $like;
}

sub find {
    my $self = shift;
    
    my @files = ();
    my @df = ();
    my $dh;
    my @dirs;
    if(defined($self->dirs())) {
        @dirs = @{$self->dirs()};
    } else {
        @dirs = ();
    }
    
    #don't repeat ourselves
    my %found_dirs = ();
    my %found_files = ();
    
    #consider each directory
    while(my $dir = shift @dirs) {
        
        #don't repeat ourselves
        next if defined($found_dirs{$dir});
        $found_dirs{$dir} = 1;
        
        #read the files from the directory, getting rid of . and ..
        opendir($dh, $dir) or Carp::croak "Could not open directory $dir for reading\n"; #should I warn here?
        @df = grep { $_ !~ /^\.$/ && $_ !~ /^\.\.$/ } readdir($dh);
        
        #append the directory name to the files
        for(my $i = 0; $i <= $#df; ++$i) {
            if($dir =~ m!/$!) {
                $df[$i] = $dir.$df[$i];
            } else {
                $df[$i] = $dir.'/'.$df[$i];
            }
        }
        
        #test each file
        foreach my $file (@df) {
            if($self->_test_like($file)
            && $self->_test_unlike($file)
            && $self->_test_ext($file)
            && $self->_test_subs($file)
            && $self->_test_size($file)
            && $self->_test_changed($file)
            && $self->_test_modified($file)
            && $self->_test_accessed($file)
            && $self->_test_is($file)
            && $self->_test_isnt($file)
            && $self->_test_owner($file)
            && $self->_test_group($file)
            && $self->_test_perms($file)) {
                push(@files, $file);
            }
            
            if($self->recurse() && -d $file) {
                push(@dirs, $file);
            }
        }
    }
    
    $self->_set_files(\@files);
        
    #return files found
    return @files;
}

sub _test_like {
    my ($self, $file) = @_;
    
    if(!$self->has_like()) { return 1; }
    
    foreach my $re (@{$self->like()}) {
        return 1 if $file =~ $re;
    }
    
    return 0;
}

sub _test_unlike {
    my ($self, $file) = @_;
    
    if(!$self->has_unlike()) { return 1; }
    
    foreach my $re (@{$self->unlike()}) {
        return 0 if $file =~ $re;
    }
    
    return 1;
}

sub _test_ext {
    my ($self, $file) = @_;
    
    if(!$self->has_ext()) { return 1; }
    
    foreach my $ext (@{$self->ext()}) {
        return 1 if $file =~ qr/${ext}$/;
    }
    
    return 0;
}

sub _test_subs {
    my ($self, $file) = @_;
    
    if(!$self->has_subs()) { return 1; }
    
    foreach my $sub (@{$self->subs()}) {
        return 1 if &$sub($file);
    }
    
    return 0;
}

sub _test_size {
    my ($self, $file) = @_;
    
    if(!$self->has_size()) { return 1; }
    
    my ($f) = File::Util->new();
    
    foreach my $size (@{$self->size()}) {
        return 0 if !Number::Compare->new($size)->test($f->size($file));
    }
    
    return 1;
}

sub _test_changed {
    my ($self, $file) = @_;
    
    if(!$self->has_changed()) { return 1; }
    
    my ($f) = File::Util->new();
    
    foreach my $date (@{$self->changed()}) {
        return 0 if !Number::Compare::Date->new($date)->test($f->last_changed($file));
    }
    
    return 1;
}

sub _test_modified {
    my ($self, $file) = @_;
    
    if(!$self->has_modified()) { return 1; }
    
    my ($f) = File::Util->new();
    
    foreach my $date (@{$self->modified()}) {
        return 0 if !Number::Compare::Date->new($date)->test($f->last_modified($file));
    }
    
    return 1;
}

sub _test_accessed {
    my ($self, $file) = @_;
    
    if(!$self->has_accessed()) { return 1; }
    
    my ($f) = File::Util->new();
    
    foreach my $date (@{$self->accessed()}) {
        return 0 if !Number::Compare::Date->new($date)->test($f->last_access($file));
    }
    
    return 1;
}

sub _test_is {
    my ($self, $file) = @_;
    
    if(!$self->has_is()) { return 1; }
    
    foreach my $directive (@{$self->is()}) {
        if($directive eq 'readable') {
            return 0 if !-r $file;
        } elsif($directive eq 'r_readable') {
            return 0 if !-R $file;
        } elsif($directive eq 'writable') {
            return 0 if !-w $file;
        } elsif($directive eq 'r_writable') {
            return 0 if !-W $file;
        } elsif($directive eq 'executable') {
            return 0 if !-x $file;
        } elsif($directive eq 'r_executable') {
            return 0 if !-X $file;
        } elsif($directive eq 'owned') {
            return 0 if !-o $file;
        } elsif($directive eq 'r_owned') {
            return 0 if !-O $file;
        } elsif($directive eq 'exists') {
            return 0 if !-e $file;
        } elsif($directive eq 'file') {
            return 0 if !-f $file;
        } elsif($directive eq 'empty') {
            return 0 if !-z $file;
        } elsif($directive eq 'directory') {
            return 0 if !-d $file;
        } elsif($directive eq 'nonempty') {
            return 0 if !-s $file;
        } elsif($directive eq 'symlink') {
            return 0 if !-l $file;
        } elsif($directive eq 'fifo') {
            return 0 if !-p $file;
        } elsif($directive eq 'setuid') {
            return 0 if !-u $file;
        } elsif($directive eq 'socket') {
            return 0 if !-S $file;
        } elsif($directive eq 'setgid') {
            return 0 if !-g $file;
        } elsif($directive eq 'block') {
            return 0 if !-b $file;
        } elsif($directive eq 'sticky') {
            return 0 if !-k $file;
        } elsif($directive eq 'character') {
            return 0 if !-c $file;
        } elsif($directive eq 'tty') {
            return 0 if !-t $file;
        } elsif($directive eq 'modified') {
            return 0 if !-M $file;
        } elsif($directive eq 'accessed') {
            return 0 if !-A $file;
        } elsif($directive eq 'ascii') {
            return 0 if !-T $file;
        } elsif($directive eq 'changed') {
            return 0 if !-C $file;
        } elsif($directive eq 'binary') {
            return 0 if !-B $file;
        }
    }
    
    return 1;
}

sub _test_isnt {
    my ($self, $file) = @_;
    
    if(!$self->has_isnt()) { return 1; }
    
    foreach my $directive (@{$self->isnt()}) {
        if($directive eq 'readable') {
            return 0 if -r $file;
        } elsif($directive eq 'r_readable') {
            return 0 if -R $file;
        } elsif($directive eq 'writable') {
            return 0 if -w $file;
        } elsif($directive eq 'r_writable') {
            return 0 if -W $file;
        } elsif($directive eq 'executable') {
            return 0 if -x $file;
        } elsif($directive eq 'r_executable') {
            return 0 if -X $file;
        } elsif($directive eq 'owned') {
            return 0 if -o $file;
        } elsif($directive eq 'r_owned') {
            return 0 if -O $file;
        } elsif($directive eq 'exists') {
            return 0 if -e $file;
        } elsif($directive eq 'file') {
            return 0 if -f $file;
        } elsif($directive eq 'empty') {
            return 0 if -z $file;
        } elsif($directive eq 'directory') {
            return 0 if -d $file;
        } elsif($directive eq 'nonempty') {
            return 0 if -s $file;
        } elsif($directive eq 'symlink') {
            return 0 if -l $file;
        } elsif($directive eq 'fifo') {
            return 0 if -p $file;
        } elsif($directive eq 'setuid') {
            return 0 if -u $file;
        } elsif($directive eq 'socket') {
            return 0 if -S $file;
        } elsif($directive eq 'setgid') {
            return 0 if -g $file;
        } elsif($directive eq 'block') {
            return 0 if -b $file;
        } elsif($directive eq 'sticky') {
            return 0 if -k $file;
        } elsif($directive eq 'character') {
            return 0 if -c $file;
        } elsif($directive eq 'tty') {
            return 0 if -t $file;
        } elsif($directive eq 'modified') {
            return 0 if -M $file;
        } elsif($directive eq 'accessed') {
            return 0 if -A $file;
        } elsif($directive eq 'ascii') {
            return 0 if -T $file;
        } elsif($directive eq 'changed') {
            return 0 if -C $file;
        } elsif($directive eq 'binary') {
            return 0 if -B $file;
        }
    }
    
    return 1;
}

sub _test_owner {
    my ($self, $file) = @_;
    
    if(!$self->has_owner()) { return 1; }
    
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
    my $name = getpwuid($uid);
    
    foreach my $owner (@{$self->owner()}) {
        return 1 if $owner eq $uid || $owner eq $name;
    }
    
    return 0;
}

sub _test_group {
    my ($self, $file) = @_;
    
    if(!$self->has_group()) { return 1; }
    
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
    my $name = getgrgid($gid);
    
    foreach my $group (@{$self->group()}) {
        return 1 if $group eq $gid || $group eq $name;
    }
    
    return 0;
}

sub _test_perms {
    my ($self, $file) = @_;
    
    if(!$self->has_perms()) { return 1; }
    
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
    $mode = $mode & 07777;
    $mode = sprintf('%03o', $mode);
    
    foreach my $perm (@{$self->perms()}) {
        return 1 if $mode == $perm || $mode eq _perm_string_to_octal($perm);
    }
}

sub _perm_string_to_octal {
    my $str = shift;
    
    if($str =~ m/^([r-][w-][x-])([r-][w-][x-])([r-][w-][x-])$/) {
    
        my $owner = $1;
        my $group = $2;
        my $other = $3;
        
        my $vals = {
            '---' => 0,
            '--x' => 1,
            '-w-' => 2,
            '-wx' => 3,
            'r--' => 4,
            'r-x' => 5,
            'rw-' => 6,
            'rwx' => 7,
        };
        
        return $vals->{$owner} * 100 + $vals->{$group} * 10 + $vals->{$other};
    }
    
    return $str;
}

1;
