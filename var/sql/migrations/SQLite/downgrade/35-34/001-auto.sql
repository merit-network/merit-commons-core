-- Convert schema '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/35/001-auto.yml' to '/Users/mikeyg/projects/meritcommons/var/sql/migrations/_source/deploy/34/001-auto.yml':;

;
BEGIN;

;
CREATE TEMPORARY TABLE meritcommons_stream_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  short_name varchar(8),
  modify_time integer NOT NULL,
  unique_id varchar(255) NOT NULL,
  common_name varchar(255) NOT NULL,
  configuration text,
  origin varchar(255),
  creator integer NOT NULL,
  single_author integer NOT NULL DEFAULT 0,
  single_subscriber integer NOT NULL DEFAULT 0,
  disabled integer NOT NULL DEFAULT 0,
  earns_return integer NOT NULL DEFAULT 1,
  toll_required integer NOT NULL DEFAULT 0,
  requires_subscriber_authorization integer NOT NULL DEFAULT 0,
  requires_author_authorization integer NOT NULL DEFAULT 0,
  allow_unsubscribe integer NOT NULL DEFAULT 1,
  allow_add_moderator integer NOT NULL DEFAULT 0,
  open_reply integer NOT NULL DEFAULT 1,
  personal_inbox_user integer,
  personal_outbox_user integer,
  notification_inbox_user integer,
  description text,
  keywords text,
  url_name varchar(255),
  type enum,
  subtype varchar(255),
  external_unique_id varchar(255),
  public_key text,
  secret_key text,
  show_publicly integer NOT NULL DEFAULT 0,
  display_subscribers integer NOT NULL DEFAULT 0,
  subscriber_count integer NOT NULL DEFAULT 0,
  author_count integer NOT NULL DEFAULT 0,
  moderator_count integer NOT NULL DEFAULT 0,
  members_can_invite integer NOT NULL DEFAULT 0,
  private integer NOT NULL DEFAULT 0,
  FOREIGN KEY (creator) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);

;
INSERT INTO meritcommons_stream_temp_alter( id, create_time, short_name, modify_time, unique_id, common_name, configuration, origin, creator, single_author, single_subscriber, disabled, earns_return, toll_required, requires_subscriber_authorization, requires_author_authorization, allow_unsubscribe, allow_add_moderator, open_reply, personal_inbox_user, personal_outbox_user, notification_inbox_user, description, keywords, url_name, type, subtype, external_unique_id, public_key, secret_key, show_publicly, display_subscribers, subscriber_count, author_count, moderator_count, members_can_invite, private) SELECT id, create_time, short_name, modify_time, unique_id, common_name, configuration, origin, creator, single_author, single_subscriber, disabled, earns_return, toll_required, requires_subscriber_authorization, requires_author_authorization, allow_unsubscribe, allow_add_moderator, open_reply, personal_inbox_user, personal_outbox_user, notification_inbox_user, description, keywords, url_name, type, subtype, external_unique_id, public_key, secret_key, show_publicly, display_subscribers, subscriber_count, author_count, moderator_count, members_can_invite, private FROM meritcommons_stream;

;
DROP TABLE meritcommons_stream;

;
CREATE TABLE meritcommons_stream (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  short_name varchar(8),
  modify_time integer NOT NULL,
  unique_id varchar(255) NOT NULL,
  common_name varchar(255) NOT NULL,
  configuration text,
  origin varchar(255),
  creator integer NOT NULL,
  single_author integer NOT NULL DEFAULT 0,
  single_subscriber integer NOT NULL DEFAULT 0,
  disabled integer NOT NULL DEFAULT 0,
  earns_return integer NOT NULL DEFAULT 1,
  toll_required integer NOT NULL DEFAULT 0,
  requires_subscriber_authorization integer NOT NULL DEFAULT 0,
  requires_author_authorization integer NOT NULL DEFAULT 0,
  allow_unsubscribe integer NOT NULL DEFAULT 1,
  allow_add_moderator integer NOT NULL DEFAULT 0,
  open_reply integer NOT NULL DEFAULT 1,
  personal_inbox_user integer,
  personal_outbox_user integer,
  notification_inbox_user integer,
  description text,
  keywords text,
  url_name varchar(255),
  type enum,
  subtype varchar(255),
  external_unique_id varchar(255),
  public_key text,
  secret_key text,
  show_publicly integer NOT NULL DEFAULT 0,
  display_subscribers integer NOT NULL DEFAULT 0,
  subscriber_count integer NOT NULL DEFAULT 0,
  author_count integer NOT NULL DEFAULT 0,
  moderator_count integer NOT NULL DEFAULT 0,
  members_can_invite integer NOT NULL DEFAULT 0,
  private integer NOT NULL DEFAULT 0,
  FOREIGN KEY (creator) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);

;
CREATE INDEX meritcommons_stream_idx_creator02 ON meritcommons_stream (creator);

;
CREATE INDEX url_name_idx02 ON meritcommons_stream (url_name);

;
CREATE INDEX url_name_type_idx02 ON meritcommons_stream (url_name, type);

;
CREATE INDEX meritcommons_stream_external_u00 ON meritcommons_stream (external_unique_id);

;
CREATE UNIQUE INDEX meritcommons_stream_external_u00 ON meritcommons_stream (external_unique_id);

;
CREATE UNIQUE INDEX meritcommons_stream_unique_id02 ON meritcommons_stream (unique_id);

;
CREATE UNIQUE INDEX meritcommons_stream_url_name02 ON meritcommons_stream (url_name);

;
INSERT INTO meritcommons_stream SELECT id, create_time, short_name, modify_time, unique_id, common_name, configuration, origin, creator, single_author, single_subscriber, disabled, earns_return, toll_required, requires_subscriber_authorization, requires_author_authorization, allow_unsubscribe, allow_add_moderator, open_reply, personal_inbox_user, personal_outbox_user, notification_inbox_user, description, keywords, url_name, type, subtype, external_unique_id, public_key, secret_key, show_publicly, display_subscribers, subscriber_count, author_count, moderator_count, members_can_invite, private FROM meritcommons_stream_temp_alter;

;
DROP TABLE meritcommons_stream_temp_alter;

;

COMMIT;

