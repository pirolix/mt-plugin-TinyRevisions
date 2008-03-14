package MT::Plugin::OMV::TinyRevisions;
########################################################################
#   TinyRevisions
#           Copyright (c) Piroli YUKARINOMIYA
########################################################################

use strict;
use warnings;
use MT 3.3;
use File::Spec;
use File::Path;
use Data::Dumper;#DEBUG
use Digest::MD5;

###
use constant BACKUP_REVISIONS => 10;

use vars qw( $NAME $VERSION );
$NAME = 'TinyRevisions';
$VERSION = '1.20';

use base qw( MT::Plugin );
my $plugin = MT::Plugin::OMV::TinyRevisions->new({
        name => $NAME,
        version => $VERSION,
        key => lc $NAME,
        id => lc $NAME,
        author_name => 'Piroli YUKARINOMIYA',
        author_link => 'http://www.magicvox.net/',
        description => <<HTMLHEREDOC,
Store the revisions of Template, Entry and Webpage.
HTMLHEREDOC
});
MT->add_plugin ($plugin);

sub instance { $plugin }



### Register callbacks
use constant CALLBACK_PRIORITY => 9;

use MT::Template;
MT::Template->add_callback( 'post_save', CALLBACK_PRIORITY, $plugin, \&_hdlr_object_post_save );



### Common handler to save the version of object
sub _hdlr_object_post_save {
    my( $cb, $obj, $org_obj ) = @_;

    my $revision_num = time;

    # MT::Template
    if( ref $obj == 'MT::Template' ) {
        my $type = 'template';
        save_revision_data( $obj, $type, $revision_num, 'text');
    }
    # MT::Entry
    elsif( ref $obj == 'MT::Entry' ) {
        my $type = 'entry';
#        save_revision_data( $obj, $type, $revision_num, 'text');
    }
    # MT::Page
    elsif( ref $obj == 'MT::Page' ) {
        my $type = 'page';
#        save_revision_data( $obj, $type, $revision_num, 'text');
    }
}



###
sub save_revision_data {
    my( $obj, $type, $revision_num, $column ) = @_;

    my $id = $obj->id;

    my $revisions_path = File::Spec->catfile(
            MT->instance->mt_dir,
            &instance->envelope,
            'versions', $type, $id );
    eval { mkpath( $revisions_path ) } unless -d $revisions_path;
    return undef if $@;

    my $plugindata_key = "${type}::${id}::${column}";
    my $prev_md5_hash = &instance->load_plugindata( $plugindata_key );
    if( defined $prev_md5_hash ) {
        my $this_md5_hash = Digest::MD5::md5_hex( $obj->$column );
        unless( $$prev_md5_hash eq $this_md5_hash ) {
            ### Anything has changed
            save_revisions_data_file( $revisions_path, $revision_num, $obj, $column );
            remove_old_revisions_data_file( $revisions_path, $column, BACKUP_REVISIONS );
            &instance->save_plugindata( $plugindata_key, \$this_md5_hash );
        }
    } else {
        ### There is no revisions. save as the first
        my $this_md5_hash = Digest::MD5::md5_hex( $obj->$column );
        save_revisions_data_file( $revisions_path, $revision_num, $obj, $column );
        remove_old_revisions_data_file( $revisions_path, $column, BACKUP_REVISIONS );
        &instance->save_plugindata( $plugindata_key, \$this_md5_hash );
    }

    ### Always be saved as the latest
    save_revisions_data_file( $revisions_path, '__latest__', $obj, $column );
}

### Save the contents into revised file
sub save_revisions_data_file {
    my( $revisions_path, $revision_num, $obj, $column ) = @_;
    my $filename = File::Spec->catfile( $revisions_path, "$revision_num.$column" );
    if( open( my $fh, ">$filename")) {
        print $fh $obj->$column;
        close $fh;
    }
}

### Leave the revisions within soecified by BACKUP_REVISIONS
sub remove_old_revisions_data_file {
    my( $revisions_path, $column, $backup ) = @_;
    if( opendir( my $dh, $revisions_path )) {
        map {
            unlink File::Spec->catfile( $revisions_path, $_ );
        } grep { --$backup < 0 }
                reverse sort grep { /\d+\.$column$/ }
                        readdir $dh;
        closedir $dh;
    }
}



### Handle MT::PluginData
use MT::PluginData;

sub load_plugindata {
    my( $plugin, $key ) = @_;

    my $plugin_data = MT::PluginData->load({
        plugin => $NAME, key => $key,
    }) or return undef;

    $plugin_data->data;
}

sub save_plugindata {
    my( $plugin, $key, $data ) = @_;

    my $plugin_data = MT::PluginData->load({
        plugin => $NAME, key => $key,
    });
    unless( $plugin_data ) {
        $plugin_data = MT::PluginData->new;
        $plugin_data->plugin( $NAME );
        $plugin_data->key( $key );
    }
    $plugin_data->data( $data );
    $plugin_data->save;
}

1;