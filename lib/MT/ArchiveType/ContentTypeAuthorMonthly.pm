# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ArchiveType::ContentTypeAuthorMonthly;

use strict;
use warnings;
use base
    qw( MT::ArchiveType::ContentTypeAuthor MT::ArchiveType::ContentTypeMonthly MT::ArchiveType::AuthorMonthly );

use MT::ContentStatus;
use MT::Util qw( start_end_month );

sub name {
    return 'ContentType-Author-Monthly';
}

sub archive_label {
    return MT->translate("CONTENTTYPE-AUTHOR-MONTHLY_ADV");
}

sub archive_short_label {
    return MT->translate("AUTHOR-MONTHLY_ADV");
}

sub order {
    return 250;
}

sub dynamic_template {
    return 'author/<$MTContentAuthorID$>/<$MTArchiveDate format="%Y%m"$>';
}

sub default_archive_templates {
    return [
        {   label           => 'author/author-basename/yyyy/mm/index.html',
            template        => 'author/%-a/%y/%m/%f',
            default         => 1,
            required_fields => { date_and_time => 1 }
        },
        {   label           => 'author/author_basename/yyyy/mm/index.html',
            template        => 'author/%a/%y/%m/%f',
            required_fields => { date_and_time => 1 }
        },
    ];
}

sub template_params {
    return {
        archive_class               => "contenttype-author-monthly-archive",
        author_monthly_archive      => 1,
        archive_template            => 1,
        archive_listing             => 1,
        author_based_archive        => 1,
        datebased_archive           => 1,
        contenttype_archive_listing => 1,
    };
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $sort_order
        = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $auth_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;

    my $tmpl  = $ctx->stash('template');
    my @data  = ();
    my $count = 0;

    my $author = $ctx->stash('author');

    my $ts    = $ctx->{current_timestamp};
    my $tsend = $ctx->{current_timestamp_end};

    my $map = $ctx->stash('template_map');
    my $dt_field_id = defined $map && $map ? $map->dt_field_id : '';
    my $content_type_id
        = $ctx->stash('content_type') ? $ctx->stash('content_type')->id : '';
    require MT::ContentData;
    require MT::ContentFieldIndex;

    my $loop_sub = sub {
        my $auth = shift;

        my $group_terms
            = $obj->make_archive_group_terms( $blog->id, $dt_field_id, $ts,
            $tsend, $auth->id, $content_type_id );
        my $group_args
            = $obj->make_archive_group_args( 'author', 'monthly',
            $map, $ts, $tsend, $args->{lastn}, $order, '' );

        my $count_iter
            = MT::ContentData->count_group_by( $group_terms, $group_args )
            or return $ctx->error("Couldn't get monthly archive list");

        while ( my @row = $count_iter->() ) {
            my $hash = {
                year   => $row[1],
                month  => $row[2],
                author => $auth,
                count  => $row[0],
            };
            push( @data, $hash );
            return $count + 1
                if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
        return $count;
    };

    # Count entry by author
    if ($author) {
        $loop_sub->($author);
    }
    else {

        # load authors
        require MT::Author;
        my $iter;
        $iter = MT::Author->load_iter(
            undef,
            {   sort      => 'name',
                direction => $auth_order,
                join      => [
                    'MT::ContentData',
                    'author_id',
                    {   status  => MT::ContentStatus::RELEASE(),
                        blog_id => $blog->id
                    },
                    { unique => 1 }
                ]
            }
        );

        while ( my $a = $iter->() ) {
            $loop_sub->($a);
            last if ( defined($limit) && $count == $limit );
        }
    }

    my $loop = @data;
    my $curr = 0;

    return sub {
        if ( $curr < $loop ) {
            my $date = sprintf(
                "%04d%02d%02d000000",
                $data[$curr]->{year},
                $data[$curr]->{month}, 1
            );
            my ( $start, $end ) = start_end_month($date);
            my $count = $data[$curr]->{count};
            my %hash  = (
                author => $data[$curr]->{author},
                year   => $data[$curr]->{year},
                month  => $data[$curr]->{month},
                start  => $start,
                end    => $end
            );
            $curr++;
            return ( $count, %hash );
        }
        undef;
        }
}

sub archive_group_contents {
    my $obj = shift;
    my ( $ctx, $param, $content_type_id ) = @_;
    Carp::confess("ctx is undef") unless defined $ctx;
    my $ts
        = $param->{year}
        ? sprintf( "%04d%02d%02d000000", $param->{year}, $param->{month}, 1 )
        : $ctx->stash('current_timestamp');
    my $author = $param->{author} || $ctx->stash('author');
    my $limit = $param->{limit};
    $obj->dated_author_contents( $ctx, 'Author-Monthly', $author, $ts,
        $limit, $content_type_id );
}

*date_range    = \&MT::ArchiveType::Monthly::date_range;
*archive_file  = \&MT::ArchiveType::AuthorMonthly::archive_file;
*archive_title = \&MT::ArchiveType::AuthorMonthly::archive_title;
*next_archive_content_data
    = \&MT::ArchiveType::ContentTypeDate::next_archive_content_data;
*previous_archive_content_data
    = \&MT::ArchiveType::ContentTypeDate::previous_archive_content_data;

1;
