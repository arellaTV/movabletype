# Movable Type (r) (C) 2006-2016 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ContentType;

use strict;
use base qw( MT::Object );

use JSON;

__PACKAGE__->install_properties(
    {   column_defs => {
            'id'         => 'integer not null auto_increment',
            'blog_id'    => 'integer not null',
            'name'       => 'string(255)',
            'version'    => 'integer',
            'unique_key' => 'blob',
            'entities'   => 'blob',
        },
        indexes     => { blog_id => 1 },
        datasource  => 'content_type',
        primary_key => 'id',
        audit       => 1,
        child_of      => [ 'MT::Blog',        'MT::Website' ],
        child_classes => [ 'MT::ContentData', 'MT::Entity', 'MT::EntityIdx' ],

    }
);

sub class_label {
    MT->translate("Content Type");
}

sub class_label_plural {
    MT->translate("Content Types");
}

sub parents {
    my $obj = shift;
    {   blog_id => {
            class    => [ MT->model('blog'), MT->model('website') ],
            optional => 1
        },
    };
}

sub entities_objs {
    my $obj = shift;
    my $entities = eval { JSON::decode_json( $obj->entities ) } || [];
    my @entities_objs
        = map { MT->model('entity')->load( $_->{id} ) } @{$entities};
    return \@entities_objs;
}

sub permissions {
    my $obj = shift;
    return +{ %{ $obj->permission }, %{ $obj->entity_permissions } };
}

sub permission {
    my $obj              = shift;
    my $permitted_action = 'manage_content_type:' . $obj->unique_key;
    my $name             = 'blog.' . $permitted_action;
    return +{
        $name => {
            group            => $obj->permission_group,
            label            => 'Manage "' . $obj->name . '" content type',
            order            => 100,
            permitted_action => { $permitted_action => 1 },
        }
    };
}

sub entity_permissions {
    my $obj = shift;
    my %permissions;
    my $order = 200;
    for my $e ( @{ $obj->entities_objs } ) {
        %permissions = ( %permissions, %{ $e->permission($order) } );
        $order += 100;
    }
    return \%permissions;
}

sub permission_group {
    my $obj = shift;
    return '"' . $obj->name . '" content type';
}

# class method
sub permission_groups {
    my $class         = shift;
    my @content_types = __PACKAGE__->load;
    my @groups        = map { $_->permission_group } @content_types;
    return \@groups;
}

# class method
sub all_permissions {
    my $class = shift;
    my @content_types
        = eval { __PACKAGE__->load }; # TODO: many error occurs without "eval" in test.
    my %all_permission = map { %{ $_->permissions } } @content_types;
    return \%all_permission;
}

sub post_save {
    my ( $cb, $obj, $original ) = @_;

    MT->app->reboot;
}

sub post_remove {
    my ( $cb, $obj, $original ) = @_;

    $obj->remove_children( { key => 'ct_id' } );

    my $perm_name = 'manage_content_type:' . $obj->unique_key;
    require MT::Role;
    my @roles = MT::Role->load_by_permission($perm_name);
    foreach my $role (@roles) {
        my $permissions = $role->permissions;
        my @permissions = split ',', $permissions;
        @permissions = grep { $_ !~ /$perm_name/ } @permissions;
        @permissions = map { $_ =~ s/'//g; $_; } @permissions;
        $role->clear_full_permissions;
        $role->set_these_permissions(@permissions);
        $role->save;
    }

    MT->app->reboot;
}

1;
