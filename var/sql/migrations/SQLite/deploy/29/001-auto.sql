-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Thu Sep 25 14:32:17 2014
-- 

;
BEGIN TRANSACTION;
--
-- Table: meritcommons_dataagent
--
CREATE TABLE meritcommons_dataagent (
  id INTEGER PRIMARY KEY NOT NULL,
  enc_pub_key varchar(255),
  sign_pub_key varchar(255),
  create_time integer NOT NULL,
  common_name varchar(255) NOT NULL,
  unique_id varchar(64) NOT NULL,
  source_user integer
);
CREATE INDEX meritcommons_dataagent_uuid_idx ON meritcommons_dataagent (unique_id);
CREATE INDEX meritcommons_dataagent_cn_idx ON meritcommons_dataagent (common_name);
--
-- Table: meritcommons_demo_attachable
--
CREATE TABLE meritcommons_demo_attachable (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  title varchar(255),
  attachment1_name varchar(255),
  attachment1_size varchar(255),
  attachment1_pretty_size varchar(255),
  attachment1_content_type varchar(255),
  attachment1_modify_time varchar(255),
  attachment2_name varchar(255),
  attachment2_size varchar(255),
  attachment2_pretty_size varchar(255),
  attachment2_content_type varchar(255),
  attachment2_modify_time varchar(255),
  attachment3_name varchar(255),
  attachment3_size varchar(255),
  attachment3_pretty_size varchar(255),
  attachment3_content_type varchar(255),
  attachment3_modify_time varchar(255)
);
--
-- Table: meritcommons_profile_standard_attribute
--
CREATE TABLE meritcommons_profile_standard_attribute (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  is_default integer NOT NULL,
  k varchar(255) NOT NULL,
  type varchar(1) NOT NULL,
  label varchar(255) NOT NULL
);
--
-- Table: meritcommons_user_identity
--
CREATE TABLE meritcommons_user_identity (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  multiplier integer NOT NULL DEFAULT 0,
  identity varchar(64) NOT NULL
);
CREATE INDEX user_identity_string_idx ON meritcommons_user_identity (identity);
--
-- Table: meritcommons_user_role
--
CREATE TABLE meritcommons_user_role (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  common_name varchar(255) NOT NULL
);
--
-- Table: meritcommons_user_tag
--
CREATE TABLE meritcommons_user_tag (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  common_name varchar(255) NOT NULL
);
--
-- Table: meritcommons_stream
--
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
  FOREIGN KEY (creator) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_idx_creator ON meritcommons_stream (creator);
CREATE INDEX url_name_idx ON meritcommons_stream (url_name);
CREATE INDEX url_name_type_idx ON meritcommons_stream (url_name, type);
CREATE INDEX meritcommons_stream_external_unique_id_idx ON meritcommons_stream (external_unique_id);
CREATE UNIQUE INDEX meritcommons_stream_external_unique_id ON meritcommons_stream (external_unique_id);
CREATE UNIQUE INDEX meritcommons_stream_unique_id ON meritcommons_stream (unique_id);
CREATE UNIQUE INDEX meritcommons_stream_url_name ON meritcommons_stream (url_name);
--
-- Table: meritcommons_user
--
CREATE TABLE meritcommons_user (
  id INTEGER PRIMARY KEY NOT NULL,
  common_name varchar(255),
  email_address varchar(255),
  organization varchar(255),
  title varchar(255),
  nick_name varchar(255),
  userid varchar(255) NOT NULL,
  create_time integer NOT NULL,
  unique_id varchar(64) NOT NULL,
  modify_time integer NOT NULL,
  last_login_time integer,
  public_key_fingerprint varchar,
  public_key text,
  secret_key text,
  visiting_user integer NOT NULL DEFAULT 0,
  home_server varchar(255),
  meritcommonscoin_balance integer NOT NULL DEFAULT 0,
  personal_inbox integer,
  personal_outbox integer,
  notification_inbox integer,
  external_unique_id varchar(255),
  identity_resource text NOT NULL,
  profile_picture_name varchar(255),
  profile_picture_size varchar(255),
  profile_picture_pretty_size varchar(255),
  profile_picture_content_type varchar(255),
  profile_picture_modify_time varchar(255),
  FOREIGN KEY (notification_inbox) REFERENCES meritcommons_stream(id) ON DELETE CASCADE,
  FOREIGN KEY (personal_inbox) REFERENCES meritcommons_stream(id) ON DELETE CASCADE,
  FOREIGN KEY (personal_outbox) REFERENCES meritcommons_stream(id) ON DELETE CASCADE
);
CREATE INDEX meritcommons_user_idx_notification_inbox ON meritcommons_user (notification_inbox);
CREATE INDEX meritcommons_user_idx_personal_inbox ON meritcommons_user (personal_inbox);
CREATE INDEX meritcommons_user_idx_personal_outbox ON meritcommons_user (personal_outbox);
CREATE INDEX userid_idx ON meritcommons_user (userid);
CREATE INDEX uuid_idx ON meritcommons_user (unique_id);
CREATE INDEX cn_idx ON meritcommons_user (common_name);
CREATE INDEX identity_resource_idx ON meritcommons_user (identity_resource);
CREATE INDEX public_key_fingerprint_idx ON meritcommons_user (public_key_fingerprint);
CREATE INDEX email_address_idx ON meritcommons_user (email_address);
CREATE INDEX meritcommons_user_external_unique_id_idx ON meritcommons_user (external_unique_id);
CREATE UNIQUE INDEX meritcommons_user_external_unique_id ON meritcommons_user (external_unique_id);
CREATE UNIQUE INDEX meritcommons_user_public_key_fingerprint ON meritcommons_user (public_key_fingerprint);
CREATE UNIQUE INDEX meritcommons_user_unique_id ON meritcommons_user (unique_id);
CREATE UNIQUE INDEX meritcommons_user_userid ON meritcommons_user (userid);
--
-- Table: meritcommons_changelog
--
CREATE TABLE meritcommons_changelog (
  id integer NOT NULL,
  actor integer NOT NULL,
  create_time integer NOT NULL,
  entity_changed varchar(64) NOT NULL,
  entity_type enum NOT NULL,
  undo_id varchar(64),
  undo_data text,
  description text,
  title varchar(255),
  FOREIGN KEY (actor) REFERENCES meritcommons_user(id)
);
CREATE INDEX meritcommons_changelog_idx_actor ON meritcommons_changelog (actor);
CREATE INDEX changelog_undo_id_idx ON meritcommons_changelog (undo_id);
CREATE INDEX changelog_create_time_idx ON meritcommons_changelog (create_time);
--
-- Table: meritcommons_link
--
CREATE TABLE meritcommons_link (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  creator integer NOT NULL,
  href text NOT NULL,
  title text NOT NULL,
  short_loc varchar(64) NOT NULL,
  keywords text,
  target varchar NOT NULL DEFAULT '_blank',
  type enum,
  FOREIGN KEY (creator) REFERENCES meritcommons_user(id)
);
CREATE INDEX meritcommons_link_idx_creator ON meritcommons_link (creator);
CREATE INDEX short_loc_idx ON meritcommons_link (short_loc);
CREATE UNIQUE INDEX shortened_location ON meritcommons_link (short_loc);
--
-- Table: meritcommons_link_collection
--
CREATE TABLE meritcommons_link_collection (
  id INTEGER PRIMARY KEY NOT NULL,
  common_name varchar(255) NOT NULL,
  creator integer NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  parent integer,
  FOREIGN KEY (creator) REFERENCES meritcommons_user(id),
  FOREIGN KEY (parent) REFERENCES meritcommons_link_collection(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_link_collection_idx_creator ON meritcommons_link_collection (creator);
CREATE INDEX meritcommons_link_collection_idx_parent ON meritcommons_link_collection (parent);
CREATE UNIQUE INDEX link_collection_hierarchy ON meritcommons_link_collection (id, parent);
--
-- Table: meritcommons_localauth
--
CREATE TABLE meritcommons_localauth (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer NOT NULL,
  password varchar(255) NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id)
);
CREATE INDEX meritcommons_localauth_idx_meritcommons_user ON meritcommons_localauth (meritcommons_user);
CREATE UNIQUE INDEX credentials ON meritcommons_localauth (meritcommons_user, password);
--
-- Table: meritcommons_session
--
CREATE TABLE meritcommons_session (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  created_from varchar(255) NOT NULL,
  heartbeat_time integer,
  heartbeat_from varchar(255) NOT NULL,
  expire_time integer NOT NULL,
  session_length integer NOT NULL,
  session_id varchar(255),
  meritcommons_user integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_session_idx_meritcommons_user ON meritcommons_session (meritcommons_user);
--
-- Table: meritcommons_stream_author
--
CREATE TABLE meritcommons_stream_author (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  meritcommons_user integer NOT NULL,
  stream integer NOT NULL,
  authorized integer NOT NULL DEFAULT 0,
  allow_edit integer NOT NULL DEFAULT 0,
  added_by integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (added_by) REFERENCES meritcommons_user(id),
  FOREIGN KEY (stream) REFERENCES meritcommons_stream(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_author_idx_meritcommons_user ON meritcommons_stream_author (meritcommons_user);
CREATE INDEX meritcommons_stream_author_idx_added_by ON meritcommons_stream_author (added_by);
CREATE INDEX meritcommons_stream_author_idx_stream ON meritcommons_stream_author (stream);
CREATE UNIQUE INDEX authorship ON meritcommons_stream_author (meritcommons_user, stream);
--
-- Table: meritcommons_stream_invite
--
CREATE TABLE meritcommons_stream_invite (
  id INTEGER PRIMARY KEY NOT NULL,
  inviter integer NOT NULL,
  invitee integer NOT NULL,
  stream integer NOT NULL,
  create_time integer NOT NULL,
  FOREIGN KEY (invitee) REFERENCES meritcommons_user(id),
  FOREIGN KEY (inviter) REFERENCES meritcommons_user(id),
  FOREIGN KEY (stream) REFERENCES meritcommons_stream(id)
);
CREATE INDEX meritcommons_stream_invite_idx_invitee ON meritcommons_stream_invite (invitee);
CREATE INDEX meritcommons_stream_invite_idx_inviter ON meritcommons_stream_invite (inviter);
CREATE INDEX meritcommons_stream_invite_idx_stream ON meritcommons_stream_invite (stream);
CREATE UNIQUE INDEX meritcommons_stream_invite_inviter_invitee_stream ON meritcommons_stream_invite (inviter, invitee, stream);
--
-- Table: meritcommons_stream_message
--
CREATE TABLE meritcommons_stream_message (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  post_time integer NOT NULL,
  submitter integer NOT NULL,
  unique_id varchar(64) NOT NULL,
  external_unique_id varchar(255),
  external_url text,
  public integer NOT NULL DEFAULT 1,
  in_reply_to varchar(64),
  render_as varchar(255) NOT NULL DEFAULT 'generic',
  gizmo_code text,
  serialized_payload text,
  original_body text,
  body text NOT NULL,
  serialized integer(2) NOT NULL,
  signature varchar(255),
  signed_by varchar(255),
  thread_id varchar(64),
  score integer NOT NULL DEFAULT 0,
  regarding varchar(64),
  about varchar(64),
  regarding_stream varchar(64),
  subtype varchar(64),
  FOREIGN KEY (about) REFERENCES meritcommons_stream_message(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (regarding) REFERENCES meritcommons_stream_message(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (in_reply_to) REFERENCES meritcommons_stream_message(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (regarding_stream) REFERENCES meritcommons_stream(unique_id),
  FOREIGN KEY (submitter) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_message_idx_about ON meritcommons_stream_message (about);
CREATE INDEX meritcommons_stream_message_idx_regarding ON meritcommons_stream_message (regarding);
CREATE INDEX meritcommons_stream_message_idx_in_reply_to ON meritcommons_stream_message (in_reply_to);
CREATE INDEX meritcommons_stream_message_idx_regarding_stream ON meritcommons_stream_message (regarding_stream);
CREATE INDEX meritcommons_stream_message_idx_submitter ON meritcommons_stream_message (submitter);
CREATE INDEX meritcommons_stream_message_thread_id_idx ON meritcommons_stream_message (thread_id);
CREATE INDEX meritcommons_stream_message_uuid_idx ON meritcommons_stream_message (unique_id);
CREATE INDEX meritcommons_stream_message_post_time_idx ON meritcommons_stream_message (post_time);
CREATE INDEX meritcommons_stream_message_modify_time_idx ON meritcommons_stream_message (modify_time);
CREATE INDEX meritcommons_stream_message_render_as_idx ON meritcommons_stream_message (render_as);
CREATE INDEX meritcommons_stream_message_subtype_idx ON meritcommons_stream_message (subtype);
CREATE INDEX meritcommons_stream_message_regarding_subtype_idx ON meritcommons_stream_message (regarding, subtype);
CREATE INDEX meritcommons_stream_message_external_unique_id_idx ON meritcommons_stream_message (external_unique_id);
CREATE UNIQUE INDEX meritcommons_stream_message_external_unique_id ON meritcommons_stream_message (external_unique_id);
CREATE UNIQUE INDEX meritcommons_stream_message_unique_id ON meritcommons_stream_message (unique_id);
--
-- Table: meritcommons_stream_moderator
--
CREATE TABLE meritcommons_stream_moderator (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  meritcommons_user integer NOT NULL,
  stream integer NOT NULL,
  allow_add_moderator integer NOT NULL DEFAULT 0,
  added_by integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (added_by) REFERENCES meritcommons_user(id),
  FOREIGN KEY (stream) REFERENCES meritcommons_stream(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_moderator_idx_meritcommons_user ON meritcommons_stream_moderator (meritcommons_user);
CREATE INDEX meritcommons_stream_moderator_idx_added_by ON meritcommons_stream_moderator (added_by);
CREATE INDEX meritcommons_stream_moderator_idx_stream ON meritcommons_stream_moderator (stream);
CREATE UNIQUE INDEX moderatorship ON meritcommons_stream_moderator (meritcommons_user, stream);
--
-- Table: meritcommons_stream_subscriber
--
CREATE TABLE meritcommons_stream_subscriber (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  meritcommons_user integer NOT NULL,
  stream integer NOT NULL,
  authorized integer NOT NULL DEFAULT 0,
  allow_history integer NOT NULL DEFAULT 1,
  added_by integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (added_by) REFERENCES meritcommons_user(id),
  FOREIGN KEY (stream) REFERENCES meritcommons_stream(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_subscriber_idx_meritcommons_user ON meritcommons_stream_subscriber (meritcommons_user);
CREATE INDEX meritcommons_stream_subscriber_idx_added_by ON meritcommons_stream_subscriber (added_by);
CREATE INDEX meritcommons_stream_subscriber_idx_stream ON meritcommons_stream_subscriber (stream);
CREATE INDEX authorized_idx ON meritcommons_stream_subscriber (authorized);
CREATE INDEX added_by_idx ON meritcommons_stream_subscriber (added_by);
CREATE INDEX user_idx ON meritcommons_stream_subscriber (meritcommons_user);
CREATE INDEX stream_idx ON meritcommons_stream_subscriber (stream);
CREATE UNIQUE INDEX subscription ON meritcommons_stream_subscriber (meritcommons_user, stream);
--
-- Table: meritcommons_stream_watcher
--
CREATE TABLE meritcommons_stream_watcher (
  id INTEGER PRIMARY KEY NOT NULL,
  target varchar(64) NOT NULL,
  watcher integer NOT NULL,
  create_time integer NOT NULL,
  FOREIGN KEY (target) REFERENCES meritcommons_stream(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (watcher) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_watcher_idx_target ON meritcommons_stream_watcher (target);
CREATE INDEX meritcommons_stream_watcher_idx_watcher ON meritcommons_stream_watcher (watcher);
CREATE UNIQUE INDEX meritcommons_stream_watcher_target_watcher ON meritcommons_stream_watcher (target, watcher);
--
-- Table: meritcommons_user_meritcommonscointransaction
--
CREATE TABLE meritcommons_user_meritcommonscointransaction (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  previous_balance real NOT NULL,
  resulting_balance real NOT NULL,
  amount real NOT NULL,
  transaction_type enum NOT NULL,
  role enum NOT NULL,
  unique_id varchar(64) NOT NULL,
  meritcommons_user integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_meritcommonscointransaction_idx_meritcommons_user ON meritcommons_user_meritcommonscointransaction (meritcommons_user);
CREATE INDEX txn_type_idx ON meritcommons_user_meritcommonscointransaction (transaction_type);
--
-- Table: meritcommons_user_alias
--
CREATE TABLE meritcommons_user_alias (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer NOT NULL,
  owner integer NOT NULL,
  used integer NOT NULL DEFAULT 0,
  common_name varchar(255) NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (owner) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_alias_idx_meritcommons_user ON meritcommons_user_alias (meritcommons_user);
CREATE INDEX meritcommons_user_alias_idx_owner ON meritcommons_user_alias (owner);
CREATE INDEX user_alias_common_name_idx ON meritcommons_user_alias (common_name);
--
-- Table: meritcommons_user_attribute
--
CREATE TABLE meritcommons_user_attribute (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer NOT NULL,
  k varchar(255) NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_attribute_idx_meritcommons_user ON meritcommons_user_attribute (meritcommons_user);
CREATE INDEX user_attribute_name_idx ON meritcommons_user_attribute (k);
CREATE INDEX user_attribute_session_idx ON meritcommons_user_attribute (meritcommons_user);
--
-- Table: meritcommons_user_group
--
CREATE TABLE meritcommons_user_group (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  common_name varchar(255) NOT NULL,
  owner integer NOT NULL,
  FOREIGN KEY (owner) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_group_idx_owner ON meritcommons_user_group (owner);
--
-- Table: meritcommons_user_watcher
--
CREATE TABLE meritcommons_user_watcher (
  id INTEGER PRIMARY KEY NOT NULL,
  target varchar(64) NOT NULL,
  watcher integer NOT NULL,
  create_time integer NOT NULL,
  FOREIGN KEY (target) REFERENCES meritcommons_user(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (watcher) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_watcher_idx_target ON meritcommons_user_watcher (target);
CREATE INDEX meritcommons_user_watcher_idx_watcher ON meritcommons_user_watcher (watcher);
CREATE UNIQUE INDEX meritcommons_user_watcher_target_watcher ON meritcommons_user_watcher (target, watcher);
--
-- Table: ap_casserver_ticket
--
CREATE TABLE ap_casserver_ticket (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer NOT NULL,
  ticket_id varchar(255) NOT NULL,
  service text NOT NULL,
  pgt_url text,
  issued_by_ticket integer,
  consumed integer NOT NULL,
  renew integer NOT NULL,
  issue_time integer NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id),
  FOREIGN KEY (issued_by_ticket) REFERENCES ap_casserver_ticket(id)
);
CREATE INDEX ap_casserver_ticket_idx_meritcommons_user ON ap_casserver_ticket (meritcommons_user);
CREATE INDEX ap_casserver_ticket_idx_issued_by_ticket ON ap_casserver_ticket (issued_by_ticket);
CREATE INDEX ap_casserver_ticket_ticket_id_idx ON ap_casserver_ticket (ticket_id);
CREATE INDEX ap_casserver_ticket_user_idx ON ap_casserver_ticket (meritcommons_user);
CREATE INDEX ap_casserver_ticket_create_time_idx ON ap_casserver_ticket (create_time);
--
-- Table: meritcommons_session_attribute
--
CREATE TABLE meritcommons_session_attribute (
  id INTEGER PRIMARY KEY NOT NULL,
  session integer NOT NULL,
  k varchar(255) NOT NULL,
  FOREIGN KEY (session) REFERENCES meritcommons_session(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_session_attribute_idx_session ON meritcommons_session_attribute (session);
CREATE INDEX session_attribute_name_idx ON meritcommons_session_attribute (k);
CREATE INDEX session_attribute_session_idx ON meritcommons_session_attribute (session);
--
-- Table: meritcommons_session_keystore
--
CREATE TABLE meritcommons_session_keystore (
  id INTEGER PRIMARY KEY NOT NULL,
  session integer NOT NULL,
  k varchar(255) NOT NULL,
  FOREIGN KEY (session) REFERENCES meritcommons_session(id) ON DELETE CASCADE
);
CREATE INDEX meritcommons_session_keystore_idx_session ON meritcommons_session_keystore (session);
--
-- Table: meritcommons_stream_message_attachment
--
CREATE TABLE meritcommons_stream_message_attachment (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18),
  uploader integer NOT NULL,
  file_name varchar(255),
  file_size varchar(255),
  file_pretty_size varchar(255),
  file_content_type varchar(255),
  file_modify_time varchar(255),
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id),
  FOREIGN KEY (uploader) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_message_attachment_idx_message ON meritcommons_stream_message_attachment (message);
CREATE INDEX meritcommons_stream_message_attachment_idx_uploader ON meritcommons_stream_message_attachment (uploader);
--
-- Table: meritcommons_stream_message_gizmo
--
CREATE TABLE meritcommons_stream_message_gizmo (
  id INTEGER PRIMARY KEY NOT NULL,
  gizmo_code text NOT NULL,
  message integer(18) NOT NULL,
  author integer NOT NULL,
  FOREIGN KEY (author) REFERENCES meritcommons_user(id),
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id)
);
CREATE INDEX meritcommons_stream_message_gizmo_idx_author ON meritcommons_stream_message_gizmo (author);
CREATE INDEX meritcommons_stream_message_gizmo_idx_message ON meritcommons_stream_message_gizmo (message);
--
-- Table: meritcommons_stream_message_info
--
CREATE TABLE meritcommons_stream_message_info (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18) NOT NULL,
  meritcommons_user integer NOT NULL,
  info text NOT NULL,
  modify_time integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id),
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id)
);
CREATE INDEX meritcommons_stream_message_info_idx_meritcommons_user ON meritcommons_stream_message_info (meritcommons_user);
CREATE INDEX meritcommons_stream_message_info_idx_message ON meritcommons_stream_message_info (message);
CREATE INDEX meritcommons_stream_message_info_message_user_idx ON meritcommons_stream_message_info (message, meritcommons_user);
--
-- Table: meritcommons_stream_message_tag
--
CREATE TABLE meritcommons_stream_message_tag (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18) NOT NULL,
  meritcommons_user integer NOT NULL,
  tag varchar(255) NOT NULL,
  modify_time integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_message_tag_idx_meritcommons_user ON meritcommons_stream_message_tag (meritcommons_user);
CREATE INDEX meritcommons_stream_message_tag_idx_message ON meritcommons_stream_message_tag (message);
CREATE INDEX meritcommons_stream_message_tag_message_user_idx ON meritcommons_stream_message_tag (message, meritcommons_user);
--
-- Table: meritcommons_stream_message_vote
--
CREATE TABLE meritcommons_stream_message_vote (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18) NOT NULL,
  voter integer NOT NULL,
  vote integer NOT NULL,
  create_time integer NOT NULL,
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (voter) REFERENCES meritcommons_user(id)
);
CREATE INDEX meritcommons_stream_message_vote_idx_message ON meritcommons_stream_message_vote (message);
CREATE INDEX meritcommons_stream_message_vote_idx_voter ON meritcommons_stream_message_vote (voter);
--
-- Table: meritcommons_stream_message_watcher
--
CREATE TABLE meritcommons_stream_message_watcher (
  id INTEGER PRIMARY KEY NOT NULL,
  target varchar(64) NOT NULL,
  watcher integer NOT NULL,
  create_time integer NOT NULL,
  FOREIGN KEY (target) REFERENCES meritcommons_stream_message(unique_id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (watcher) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_message_watcher_idx_target ON meritcommons_stream_message_watcher (target);
CREATE INDEX meritcommons_stream_message_watcher_idx_watcher ON meritcommons_stream_message_watcher (watcher);
CREATE UNIQUE INDEX meritcommons_stream_message_watcher_target_watcher ON meritcommons_stream_message_watcher (target, watcher);
--
-- Table: meritcommons_stream_messagestream
--
CREATE TABLE meritcommons_stream_messagestream (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18) NOT NULL,
  stream integer NOT NULL,
  create_time integer,
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (stream) REFERENCES meritcommons_stream(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_messagestream_idx_message ON meritcommons_stream_messagestream (message);
CREATE INDEX meritcommons_stream_messagestream_idx_stream ON meritcommons_stream_messagestream (stream);
CREATE INDEX create_time_idx ON meritcommons_stream_messagestream (create_time);
CREATE INDEX meritcommons_stream_messagestream_idx_stream_message ON meritcommons_stream_messagestream (message, stream);
--
-- Table: meritcommons_user_attribute_value
--
CREATE TABLE meritcommons_user_attribute_value (
  id INTEGER PRIMARY KEY NOT NULL,
  attribute integer NOT NULL,
  v text NOT NULL,
  FOREIGN KEY (attribute) REFERENCES meritcommons_user_attribute(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_attribute_value_idx_attribute ON meritcommons_user_attribute_value (attribute);
CREATE INDEX user_attribute_idx ON meritcommons_user_attribute_value (attribute);
--
-- Table: meritcommons_user_role_exception
--
CREATE TABLE meritcommons_user_role_exception (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer NOT NULL,
  role integer NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id),
  FOREIGN KEY (role) REFERENCES meritcommons_user_role(id)
);
CREATE INDEX meritcommons_user_role_exception_idx_meritcommons_user ON meritcommons_user_role_exception (meritcommons_user);
CREATE INDEX meritcommons_user_role_exception_idx_role ON meritcommons_user_role_exception (role);
CREATE UNIQUE INDEX role_exception ON meritcommons_user_role_exception (meritcommons_user, role);
--
-- Table: meritcommons_link_click
--
CREATE TABLE meritcommons_link_click (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  identity integer,
  link integer NOT NULL,
  counter integer NOT NULL,
  FOREIGN KEY (identity) REFERENCES meritcommons_user_identity(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (link) REFERENCES meritcommons_link(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_link_click_idx_identity ON meritcommons_link_click (identity);
CREATE INDEX meritcommons_link_click_idx_link ON meritcommons_link_click (link);
CREATE INDEX user_identity_idx ON meritcommons_link_click (identity);
--
-- Table: meritcommons_link_collection_member
--
CREATE TABLE meritcommons_link_collection_member (
  id INTEGER PRIMARY KEY NOT NULL,
  link integer NOT NULL,
  collection integer NOT NULL,
  FOREIGN KEY (collection) REFERENCES meritcommons_link_collection(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (link) REFERENCES meritcommons_link(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_link_collection_member_idx_collection ON meritcommons_link_collection_member (collection);
CREATE INDEX meritcommons_link_collection_member_idx_link ON meritcommons_link_collection_member (link);
CREATE UNIQUE INDEX link_collection_membership ON meritcommons_link_collection_member (link, collection);
--
-- Table: meritcommons_link_collection_role
--
CREATE TABLE meritcommons_link_collection_role (
  id INTEGER PRIMARY KEY NOT NULL,
  role integer NOT NULL,
  collection integer NOT NULL,
  FOREIGN KEY (collection) REFERENCES meritcommons_link_collection(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (role) REFERENCES meritcommons_user_role(id)
);
CREATE INDEX meritcommons_link_collection_role_idx_collection ON meritcommons_link_collection_role (collection);
CREATE INDEX meritcommons_link_collection_role_idx_role ON meritcommons_link_collection_role (role);
CREATE UNIQUE INDEX collection_roles ON meritcommons_link_collection_role (role, collection);
--
-- Table: meritcommons_link_role
--
CREATE TABLE meritcommons_link_role (
  id INTEGER PRIMARY KEY NOT NULL,
  role integer NOT NULL,
  link integer NOT NULL,
  FOREIGN KEY (link) REFERENCES meritcommons_link(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (role) REFERENCES meritcommons_user_role(id)
);
CREATE INDEX meritcommons_link_role_idx_link ON meritcommons_link_role (link);
CREATE INDEX meritcommons_link_role_idx_role ON meritcommons_link_role (role);
CREATE UNIQUE INDEX link_roles ON meritcommons_link_role (role, link);
--
-- Table: meritcommons_session_attribute_value
--
CREATE TABLE meritcommons_session_attribute_value (
  id INTEGER PRIMARY KEY NOT NULL,
  attribute integer NOT NULL,
  v text NOT NULL,
  FOREIGN KEY (attribute) REFERENCES meritcommons_session_attribute(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_session_attribute_value_idx_attribute ON meritcommons_session_attribute_value (attribute);
CREATE INDEX session_attribute_idx ON meritcommons_session_attribute_value (attribute);
--
-- Table: meritcommons_stream_messagelink
--
CREATE TABLE meritcommons_stream_messagelink (
  id INTEGER PRIMARY KEY NOT NULL,
  message integer(18) NOT NULL,
  link integer NOT NULL,
  FOREIGN KEY (link) REFERENCES meritcommons_link(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (message) REFERENCES meritcommons_stream_message(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_stream_messagelink_idx_link ON meritcommons_stream_messagelink (link);
CREATE INDEX meritcommons_stream_messagelink_idx_message ON meritcommons_stream_messagelink (message);
CREATE INDEX messagelink_link_idx ON meritcommons_stream_messagelink (link);
CREATE INDEX messagelink_message_idx ON meritcommons_stream_messagelink (message);
--
-- Table: meritcommons_user_profile_attribute
--
CREATE TABLE meritcommons_user_profile_attribute (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  standard_attribute integer,
  user_attribute integer NOT NULL,
  type varchar(1) NOT NULL,
  attr_group varchar(255) NOT NULL,
  label varchar(255) NOT NULL,
  FOREIGN KEY (standard_attribute) REFERENCES meritcommons_profile_standard_attribute(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (user_attribute) REFERENCES meritcommons_user_attribute(id)
);
CREATE INDEX meritcommons_user_profile_attribute_idx_standard_attribute ON meritcommons_user_profile_attribute (standard_attribute);
CREATE INDEX meritcommons_user_profile_attribute_idx_user_attribute ON meritcommons_user_profile_attribute (user_attribute);
--
-- Table: meritcommons_user_assignment
--
CREATE TABLE meritcommons_user_assignment (
  id INTEGER PRIMARY KEY NOT NULL,
  meritcommons_user integer,
  grp integer,
  role integer,
  tag integer,
  identity integer,
  FOREIGN KEY (meritcommons_user) REFERENCES meritcommons_user(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (grp) REFERENCES meritcommons_user_group(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (identity) REFERENCES meritcommons_user_identity(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (role) REFERENCES meritcommons_user_role(id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX meritcommons_user_assignment_idx_meritcommons_user ON meritcommons_user_assignment (meritcommons_user);
CREATE INDEX meritcommons_user_assignment_idx_grp ON meritcommons_user_assignment (grp);
CREATE INDEX meritcommons_user_assignment_idx_identity ON meritcommons_user_assignment (identity);
CREATE INDEX meritcommons_user_assignment_idx_role ON meritcommons_user_assignment (role);
CREATE UNIQUE INDEX user_group ON meritcommons_user_assignment (meritcommons_user, grp);
CREATE UNIQUE INDEX user_identity ON meritcommons_user_assignment (meritcommons_user, identity);
CREATE UNIQUE INDEX user_role ON meritcommons_user_assignment (meritcommons_user, role);
CREATE UNIQUE INDEX user_tag ON meritcommons_user_assignment (meritcommons_user, tag);
--
-- Table: meritcommons_user_profile_attribute_value
--
CREATE TABLE meritcommons_user_profile_attribute_value (
  id INTEGER PRIMARY KEY NOT NULL,
  create_time integer NOT NULL,
  modify_time integer NOT NULL,
  profile_attribute integer NOT NULL,
  user_attribute_value integer NOT NULL,
  ordinal integer NOT NULL,
  FOREIGN KEY (profile_attribute) REFERENCES meritcommons_user_profile_attribute(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (user_attribute_value) REFERENCES meritcommons_user_attribute_value(id)
);
CREATE INDEX meritcommons_user_profile_attribute_value_idx_profile_attribute ON meritcommons_user_profile_attribute_value (profile_attribute);
CREATE INDEX meritcommons_user_profile_attribute_value_idx_user_attribute_value ON meritcommons_user_profile_attribute_value (user_attribute_value);
COMMIT;
