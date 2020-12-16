-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Feb 10 16:13:05 2014
-- 
;
--
-- Table: meritcommons_dataagent.
--
CREATE TABLE "meritcommons_dataagent" (
  "id" serial NOT NULL,
  "enc_pub_key" character varying(255),
  "sign_pub_key" character varying(255),
  "create_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "source_user" integer,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_dataagent_uuid_idx" on "meritcommons_dataagent" ("unique_id");
CREATE INDEX "meritcommons_dataagent_cn_idx" on "meritcommons_dataagent" ("common_name");

;
--
-- Table: meritcommons_demo_attachable.
--
CREATE TABLE "meritcommons_demo_attachable" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "title" character varying(255),
  "attachment1_name" character varying(255),
  "attachment1_size" character varying(255),
  "attachment1_pretty_size" character varying(255),
  "attachment1_content_type" character varying(255),
  "attachment1_modify_time" character varying(255),
  "attachment2_name" character varying(255),
  "attachment2_size" character varying(255),
  "attachment2_pretty_size" character varying(255),
  "attachment2_content_type" character varying(255),
  "attachment2_modify_time" character varying(255),
  "attachment3_name" character varying(255),
  "attachment3_size" character varying(255),
  "attachment3_pretty_size" character varying(255),
  "attachment3_content_type" character varying(255),
  "attachment3_modify_time" character varying(255),
  PRIMARY KEY ("id")
);

;
--
-- Table: meritcommons_profile_standard_attribute.
--
CREATE TABLE "meritcommons_profile_standard_attribute" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "is_default" integer NOT NULL,
  "k" character varying(255) NOT NULL,
  "type" character varying(1) NOT NULL,
  "label" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);

;
--
-- Table: meritcommons_user_identity.
--
CREATE TABLE "meritcommons_user_identity" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "multiplier" integer DEFAULT 0 NOT NULL,
  "identity" character varying(64) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "user_identity_string_idx" on "meritcommons_user_identity" ("identity");

;
--
-- Table: meritcommons_user_role.
--
CREATE TABLE "meritcommons_user_role" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);

;
--
-- Table: meritcommons_user_tag.
--
CREATE TABLE "meritcommons_user_tag" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);

;
--
-- Table: meritcommons_stream.
--
CREATE TABLE "meritcommons_stream" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "unique_id" character varying(255) NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "configuration" text,
  "origin" character varying(255),
  "creator" integer NOT NULL,
  "single_author" integer DEFAULT 0 NOT NULL,
  "single_subscriber" integer DEFAULT 0 NOT NULL,
  "disabled" integer DEFAULT 0 NOT NULL,
  "earns_return" integer DEFAULT 1 NOT NULL,
  "toll_required" integer DEFAULT 0 NOT NULL,
  "requires_subscriber_authorization" integer DEFAULT 0 NOT NULL,
  "requires_author_authorization" integer DEFAULT 0 NOT NULL,
  "allow_unsubscribe" integer DEFAULT 1 NOT NULL,
  "open_reply" integer DEFAULT 1 NOT NULL,
  "personal_inbox_user" integer,
  "personal_outbox_user" integer,
  "notification_inbox_user" integer,
  "description" text,
  "keywords" text,
  "url_name" character varying(255),
  "type" character varying,
  "external_unique_id" character varying(255),
  "public_key" text,
  "secret_key" text,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_stream_external_unique_id" UNIQUE ("external_unique_id"),
  CONSTRAINT "meritcommons_stream_unique_id" UNIQUE ("unique_id"),
  CONSTRAINT "meritcommons_stream_url_name" UNIQUE ("url_name")
);
CREATE INDEX "meritcommons_stream_idx_creator" on "meritcommons_stream" ("creator");
CREATE INDEX "url_name_idx" on "meritcommons_stream" ("url_name");
CREATE INDEX "url_name_type_idx" on "meritcommons_stream" ("url_name", "type");
CREATE INDEX "meritcommons_stream_external_unique_id_idx" on "meritcommons_stream" ("external_unique_id");

;
--
-- Table: meritcommons_user.
--
CREATE TABLE "meritcommons_user" (
  "id" serial NOT NULL,
  "common_name" character varying(255),
  "email_address" character varying(255),
  "organization" character varying(255),
  "title" character varying(255),
  "nick_name" character varying(255),
  "userid" character varying(255) NOT NULL,
  "create_time" integer NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "modify_time" integer NOT NULL,
  "last_login_time" integer,
  "public_key_fingerprint" character varying,
  "public_key" text,
  "secret_key" text,
  "visiting_user" integer DEFAULT 0 NOT NULL,
  "home_server" character varying(255),
  "meritcommonscoin_balance" integer DEFAULT 0 NOT NULL,
  "personal_inbox" integer,
  "personal_outbox" integer,
  "notification_inbox" integer,
  "external_unique_id" character varying(255),
  "identity_resource" text NOT NULL,
  "profile_picture_name" character varying(255),
  "profile_picture_size" character varying(255),
  "profile_picture_pretty_size" character varying(255),
  "profile_picture_content_type" character varying(255),
  "profile_picture_modify_time" character varying(255),
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_user_external_unique_id" UNIQUE ("external_unique_id"),
  CONSTRAINT "meritcommons_user_public_key_fingerprint" UNIQUE ("public_key_fingerprint"),
  CONSTRAINT "meritcommons_user_unique_id" UNIQUE ("unique_id"),
  CONSTRAINT "meritcommons_user_userid" UNIQUE ("userid")
);
CREATE INDEX "meritcommons_user_idx_notification_inbox" on "meritcommons_user" ("notification_inbox");
CREATE INDEX "meritcommons_user_idx_personal_inbox" on "meritcommons_user" ("personal_inbox");
CREATE INDEX "meritcommons_user_idx_personal_outbox" on "meritcommons_user" ("personal_outbox");
CREATE INDEX "userid_idx" on "meritcommons_user" ("userid");
CREATE INDEX "uuid_idx" on "meritcommons_user" ("unique_id");
CREATE INDEX "cn_idx" on "meritcommons_user" ("common_name");
CREATE INDEX "identity_resource_idx" on "meritcommons_user" ("identity_resource");
CREATE INDEX "public_key_fingerprint_idx" on "meritcommons_user" ("public_key_fingerprint");
CREATE INDEX "email_address_idx" on "meritcommons_user" ("email_address");
CREATE INDEX "meritcommons_user_external_unique_id_idx" on "meritcommons_user" ("external_unique_id");

;
--
-- Table: meritcommons_link.
--
CREATE TABLE "meritcommons_link" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "creator" integer NOT NULL,
  "href" text NOT NULL,
  "title" text NOT NULL,
  "short_loc" character varying(64) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "shortened_location" UNIQUE ("short_loc")
);
CREATE INDEX "meritcommons_link_idx_creator" on "meritcommons_link" ("creator");
CREATE INDEX "short_loc_idx" on "meritcommons_link" ("short_loc");

;
--
-- Table: meritcommons_link_collection.
--
CREATE TABLE "meritcommons_link_collection" (
  "id" serial NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "creator" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "parent" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "link_collection_hierarchy" UNIQUE ("id", "parent")
);
CREATE INDEX "meritcommons_link_collection_idx_creator" on "meritcommons_link_collection" ("creator");
CREATE INDEX "meritcommons_link_collection_idx_parent" on "meritcommons_link_collection" ("parent");

;
--
-- Table: meritcommons_localauth.
--
CREATE TABLE "meritcommons_localauth" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "password" character varying(255) NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "credentials" UNIQUE ("meritcommons_user", "password")
);
CREATE INDEX "meritcommons_localauth_idx_meritcommons_user" on "meritcommons_localauth" ("meritcommons_user");

;
--
-- Table: meritcommons_session.
--
CREATE TABLE "meritcommons_session" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "created_from" character varying(255) NOT NULL,
  "heartbeat_time" integer,
  "heartbeat_from" character varying(255) NOT NULL,
  "expire_time" integer NOT NULL,
  "session_length" integer NOT NULL,
  "session_id" character varying(255),
  "meritcommons_user" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_session_idx_meritcommons_user" on "meritcommons_session" ("meritcommons_user");

;
--
-- Table: meritcommons_stream_author.
--
CREATE TABLE "meritcommons_stream_author" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "stream" integer NOT NULL,
  "authorized" integer DEFAULT 0 NOT NULL,
  "allow_edit" integer DEFAULT 0 NOT NULL,
  "added_by" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "authorship" UNIQUE ("meritcommons_user", "stream")
);
CREATE INDEX "meritcommons_stream_author_idx_meritcommons_user" on "meritcommons_stream_author" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_author_idx_added_by" on "meritcommons_stream_author" ("added_by");
CREATE INDEX "meritcommons_stream_author_idx_stream" on "meritcommons_stream_author" ("stream");

;
--
-- Table: meritcommons_stream_message.
--
CREATE TABLE "meritcommons_stream_message" (
  "id" bigserial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "post_time" integer NOT NULL,
  "submitter" integer NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "external_unique_id" character varying(255),
  "external_url" text,
  "public" integer DEFAULT 1 NOT NULL,
  "in_reply_to" character varying(64),
  "render_as" character varying(255) DEFAULT 'generic' NOT NULL,
  "gizmo_code" text,
  "serialized_payload" text,
  "original_body" text,
  "body" text NOT NULL,
  "serialized" smallint NOT NULL,
  "signature" character varying(255),
  "signed_by" character varying(255),
  "thread_id" character varying(64),
  "score" integer DEFAULT 0 NOT NULL,
  "regarding" character varying(64),
  "regarding_stream" character varying(64),
  "subtype" character varying(64),
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_stream_message_external_unique_id" UNIQUE ("external_unique_id"),
  CONSTRAINT "meritcommons_stream_message_unique_id" UNIQUE ("unique_id")
);
CREATE INDEX "meritcommons_stream_message_idx_regarding" on "meritcommons_stream_message" ("regarding");
CREATE INDEX "meritcommons_stream_message_idx_in_reply_to" on "meritcommons_stream_message" ("in_reply_to");
CREATE INDEX "meritcommons_stream_message_idx_submitter" on "meritcommons_stream_message" ("submitter");
CREATE INDEX "meritcommons_stream_message_thread_id_idx" on "meritcommons_stream_message" ("thread_id");
CREATE INDEX "meritcommons_stream_message_uuid_idx" on "meritcommons_stream_message" ("unique_id");
CREATE INDEX "meritcommons_stream_message_post_time_idx" on "meritcommons_stream_message" ("post_time");
CREATE INDEX "meritcommons_stream_message_modify_time_idx" on "meritcommons_stream_message" ("modify_time");
CREATE INDEX "meritcommons_stream_message_render_as_idx" on "meritcommons_stream_message" ("render_as");
CREATE INDEX "meritcommons_stream_message_subtype_idx" on "meritcommons_stream_message" ("subtype");
CREATE INDEX "meritcommons_stream_message_regarding_subtype_idx" on "meritcommons_stream_message" ("regarding", "subtype");
CREATE INDEX "meritcommons_stream_message_external_unique_id_idx" on "meritcommons_stream_message" ("external_unique_id");

;
--
-- Table: meritcommons_stream_moderator.
--
CREATE TABLE "meritcommons_stream_moderator" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "stream" integer NOT NULL,
  "allow_add_moderator" integer DEFAULT 0 NOT NULL,
  "added_by" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "moderatorship" UNIQUE ("meritcommons_user", "stream")
);
CREATE INDEX "meritcommons_stream_moderator_idx_meritcommons_user" on "meritcommons_stream_moderator" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_moderator_idx_added_by" on "meritcommons_stream_moderator" ("added_by");
CREATE INDEX "meritcommons_stream_moderator_idx_stream" on "meritcommons_stream_moderator" ("stream");

;
--
-- Table: meritcommons_stream_subscriber.
--
CREATE TABLE "meritcommons_stream_subscriber" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "stream" integer NOT NULL,
  "authorized" integer DEFAULT 0 NOT NULL,
  "allow_history" integer DEFAULT 1 NOT NULL,
  "added_by" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "subscription" UNIQUE ("meritcommons_user", "stream")
);
CREATE INDEX "meritcommons_stream_subscriber_idx_meritcommons_user" on "meritcommons_stream_subscriber" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_subscriber_idx_added_by" on "meritcommons_stream_subscriber" ("added_by");
CREATE INDEX "meritcommons_stream_subscriber_idx_stream" on "meritcommons_stream_subscriber" ("stream");
CREATE INDEX "authorized_idx" on "meritcommons_stream_subscriber" ("authorized");
CREATE INDEX "added_by_idx" on "meritcommons_stream_subscriber" ("added_by");
CREATE INDEX "user_idx" on "meritcommons_stream_subscriber" ("meritcommons_user");
CREATE INDEX "stream_idx" on "meritcommons_stream_subscriber" ("stream");

;
--
-- Table: meritcommons_stream_watcher.
--
CREATE TABLE "meritcommons_stream_watcher" (
  "id" serial NOT NULL,
  "target" character varying(64) NOT NULL,
  "watcher" integer NOT NULL,
  "create_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_stream_watcher_target_watcher" UNIQUE ("target", "watcher")
);
CREATE INDEX "meritcommons_stream_watcher_idx_target" on "meritcommons_stream_watcher" ("target");
CREATE INDEX "meritcommons_stream_watcher_idx_watcher" on "meritcommons_stream_watcher" ("watcher");

;
--
-- Table: meritcommons_user_meritcommonscointransaction.
--
CREATE TABLE "meritcommons_user_meritcommonscointransaction" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "previous_balance" numeric NOT NULL,
  "resulting_balance" numeric NOT NULL,
  "amount" numeric NOT NULL,
  "transaction_type" character varying NOT NULL,
  "role" character varying NOT NULL,
  "unique_id" character varying(64) NOT NULL,
  "meritcommons_user" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_meritcommonscointransaction_idx_meritcommons_user" on "meritcommons_user_meritcommonscointransaction" ("meritcommons_user");
CREATE INDEX "txn_type_idx" on "meritcommons_user_meritcommonscointransaction" ("transaction_type");

;
--
-- Table: meritcommons_user_alias.
--
CREATE TABLE "meritcommons_user_alias" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "owner" integer NOT NULL,
  "used" integer DEFAULT 0 NOT NULL,
  "common_name" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_alias_idx_meritcommons_user" on "meritcommons_user_alias" ("meritcommons_user");
CREATE INDEX "meritcommons_user_alias_idx_owner" on "meritcommons_user_alias" ("owner");
CREATE INDEX "user_alias_common_name_idx" on "meritcommons_user_alias" ("common_name");

;
--
-- Table: meritcommons_user_attribute.
--
CREATE TABLE "meritcommons_user_attribute" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "k" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_attribute_idx_meritcommons_user" on "meritcommons_user_attribute" ("meritcommons_user");
CREATE INDEX "user_attribute_name_idx" on "meritcommons_user_attribute" ("k");
CREATE INDEX "user_attribute_session_idx" on "meritcommons_user_attribute" ("meritcommons_user");

;
--
-- Table: meritcommons_user_group.
--
CREATE TABLE "meritcommons_user_group" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "common_name" character varying(255) NOT NULL,
  "owner" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_group_idx_owner" on "meritcommons_user_group" ("owner");

;
--
-- Table: meritcommons_user_watcher.
--
CREATE TABLE "meritcommons_user_watcher" (
  "id" serial NOT NULL,
  "target" character varying(64) NOT NULL,
  "watcher" integer NOT NULL,
  "create_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_user_watcher_target_watcher" UNIQUE ("target", "watcher")
);
CREATE INDEX "meritcommons_user_watcher_idx_target" on "meritcommons_user_watcher" ("target");
CREATE INDEX "meritcommons_user_watcher_idx_watcher" on "meritcommons_user_watcher" ("watcher");

;
--
-- Table: ap_casserver_ticket.
--
CREATE TABLE "ap_casserver_ticket" (
  "id" serial NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "ticket_id" character varying(255) NOT NULL,
  "service" character varying(255) NOT NULL,
  "pgt_url" character varying(255),
  "issued_by_ticket" integer,
  "consumed" integer NOT NULL,
  "renew" integer NOT NULL,
  "issue_time" integer NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "ap_casserver_ticket_idx_meritcommons_user" on "ap_casserver_ticket" ("meritcommons_user");
CREATE INDEX "ap_casserver_ticket_idx_issued_by_ticket" on "ap_casserver_ticket" ("issued_by_ticket");
CREATE INDEX "ap_casserver_ticket_ticket_id_idx" on "ap_casserver_ticket" ("ticket_id");
CREATE INDEX "ap_casserver_ticket_user_idx" on "ap_casserver_ticket" ("meritcommons_user");
CREATE INDEX "ap_casserver_ticket_create_time_idx" on "ap_casserver_ticket" ("create_time");

;
--
-- Table: meritcommons_session_attribute.
--
CREATE TABLE "meritcommons_session_attribute" (
  "id" serial NOT NULL,
  "session" integer NOT NULL,
  "k" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_session_attribute_idx_session" on "meritcommons_session_attribute" ("session");
CREATE INDEX "session_attribute_name_idx" on "meritcommons_session_attribute" ("k");
CREATE INDEX "session_attribute_session_idx" on "meritcommons_session_attribute" ("session");

;
--
-- Table: meritcommons_session_keystore.
--
CREATE TABLE "meritcommons_session_keystore" (
  "id" serial NOT NULL,
  "session" integer NOT NULL,
  "k" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_session_keystore_idx_session" on "meritcommons_session_keystore" ("session");

;
--
-- Table: meritcommons_stream_message_attachment.
--
CREATE TABLE "meritcommons_stream_message_attachment" (
  "id" bigserial NOT NULL,
  "message" bigint,
  "uploader" integer NOT NULL,
  "file_name" character varying(255),
  "file_size" character varying(255),
  "file_pretty_size" character varying(255),
  "file_content_type" character varying(255),
  "file_modify_time" character varying(255),
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_attachment_idx_message" on "meritcommons_stream_message_attachment" ("message");
CREATE INDEX "meritcommons_stream_message_attachment_idx_uploader" on "meritcommons_stream_message_attachment" ("uploader");

;
--
-- Table: meritcommons_stream_message_gizmo.
--
CREATE TABLE "meritcommons_stream_message_gizmo" (
  "id" bigserial NOT NULL,
  "gizmo_code" text NOT NULL,
  "message" bigint NOT NULL,
  "author" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_gizmo_idx_author" on "meritcommons_stream_message_gizmo" ("author");
CREATE INDEX "meritcommons_stream_message_gizmo_idx_message" on "meritcommons_stream_message_gizmo" ("message");

;
--
-- Table: meritcommons_stream_message_info.
--
CREATE TABLE "meritcommons_stream_message_info" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "info" text NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_info_idx_meritcommons_user" on "meritcommons_stream_message_info" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_message_info_idx_message" on "meritcommons_stream_message_info" ("message");
CREATE INDEX "meritcommons_stream_message_info_message_user_idx" on "meritcommons_stream_message_info" ("message", "meritcommons_user");

;
--
-- Table: meritcommons_stream_message_tag.
--
CREATE TABLE "meritcommons_stream_message_tag" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "meritcommons_user" integer NOT NULL,
  "tag" character varying(255) NOT NULL,
  "modify_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_tag_idx_meritcommons_user" on "meritcommons_stream_message_tag" ("meritcommons_user");
CREATE INDEX "meritcommons_stream_message_tag_idx_message" on "meritcommons_stream_message_tag" ("message");
CREATE INDEX "meritcommons_stream_message_tag_message_user_idx" on "meritcommons_stream_message_tag" ("message", "meritcommons_user");

;
--
-- Table: meritcommons_stream_message_vote.
--
CREATE TABLE "meritcommons_stream_message_vote" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "voter" integer NOT NULL,
  "vote" integer NOT NULL,
  "create_time" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_message_vote_idx_message" on "meritcommons_stream_message_vote" ("message");
CREATE INDEX "meritcommons_stream_message_vote_idx_voter" on "meritcommons_stream_message_vote" ("voter");

;
--
-- Table: meritcommons_stream_message_watcher.
--
CREATE TABLE "meritcommons_stream_message_watcher" (
  "id" serial NOT NULL,
  "target" character varying(64) NOT NULL,
  "watcher" integer NOT NULL,
  "create_time" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "meritcommons_stream_message_watcher_target_watcher" UNIQUE ("target", "watcher")
);
CREATE INDEX "meritcommons_stream_message_watcher_idx_target" on "meritcommons_stream_message_watcher" ("target");
CREATE INDEX "meritcommons_stream_message_watcher_idx_watcher" on "meritcommons_stream_message_watcher" ("watcher");

;
--
-- Table: meritcommons_stream_messagestream.
--
CREATE TABLE "meritcommons_stream_messagestream" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "stream" integer NOT NULL,
  "create_time" integer,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_messagestream_idx_message" on "meritcommons_stream_messagestream" ("message");
CREATE INDEX "meritcommons_stream_messagestream_idx_stream" on "meritcommons_stream_messagestream" ("stream");
CREATE INDEX "create_time_idx" on "meritcommons_stream_messagestream" ("create_time");

;
--
-- Table: meritcommons_user_attribute_value.
--
CREATE TABLE "meritcommons_user_attribute_value" (
  "id" serial NOT NULL,
  "attribute" integer NOT NULL,
  "v" text NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_attribute_value_idx_attribute" on "meritcommons_user_attribute_value" ("attribute");
CREATE INDEX "user_attribute_idx" on "meritcommons_user_attribute_value" ("attribute");

;
--
-- Table: meritcommons_link_click.
--
CREATE TABLE "meritcommons_link_click" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "identity" integer,
  "link" integer NOT NULL,
  "counter" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_link_click_idx_identity" on "meritcommons_link_click" ("identity");
CREATE INDEX "meritcommons_link_click_idx_link" on "meritcommons_link_click" ("link");
CREATE INDEX "user_identity_idx" on "meritcommons_link_click" ("identity");

;
--
-- Table: meritcommons_link_collection_member.
--
CREATE TABLE "meritcommons_link_collection_member" (
  "id" serial NOT NULL,
  "link" integer NOT NULL,
  "collection" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "link_collection_membership" UNIQUE ("link", "collection")
);
CREATE INDEX "meritcommons_link_collection_member_idx_collection" on "meritcommons_link_collection_member" ("collection");
CREATE INDEX "meritcommons_link_collection_member_idx_link" on "meritcommons_link_collection_member" ("link");

;
--
-- Table: meritcommons_link_collection_role.
--
CREATE TABLE "meritcommons_link_collection_role" (
  "id" serial NOT NULL,
  "role" integer NOT NULL,
  "collection" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "link_roles" UNIQUE ("role", "collection")
);
CREATE INDEX "meritcommons_link_collection_role_idx_collection" on "meritcommons_link_collection_role" ("collection");
CREATE INDEX "meritcommons_link_collection_role_idx_role" on "meritcommons_link_collection_role" ("role");

;
--
-- Table: meritcommons_session_attribute_value.
--
CREATE TABLE "meritcommons_session_attribute_value" (
  "id" serial NOT NULL,
  "attribute" integer NOT NULL,
  "v" text NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_session_attribute_value_idx_attribute" on "meritcommons_session_attribute_value" ("attribute");
CREATE INDEX "session_attribute_idx" on "meritcommons_session_attribute_value" ("attribute");

;
--
-- Table: meritcommons_stream_messagelink.
--
CREATE TABLE "meritcommons_stream_messagelink" (
  "id" bigserial NOT NULL,
  "message" bigint NOT NULL,
  "link" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_stream_messagelink_idx_link" on "meritcommons_stream_messagelink" ("link");
CREATE INDEX "meritcommons_stream_messagelink_idx_message" on "meritcommons_stream_messagelink" ("message");
CREATE INDEX "messagelink_link_idx" on "meritcommons_stream_messagelink" ("link");
CREATE INDEX "messagelink_message_idx" on "meritcommons_stream_messagelink" ("message");

;
--
-- Table: meritcommons_user_profile_attribute.
--
CREATE TABLE "meritcommons_user_profile_attribute" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "standard_attribute" integer,
  "user_attribute" integer NOT NULL,
  "type" character varying(1) NOT NULL,
  "attr_group" character varying(255) NOT NULL,
  "label" character varying(255) NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_profile_attribute_idx_standard_attribute" on "meritcommons_user_profile_attribute" ("standard_attribute");
CREATE INDEX "meritcommons_user_profile_attribute_idx_user_attribute" on "meritcommons_user_profile_attribute" ("user_attribute");

;
--
-- Table: meritcommons_user_assignment.
--
CREATE TABLE "meritcommons_user_assignment" (
  "id" serial NOT NULL,
  "meritcommons_user" integer,
  "grp" integer,
  "role" integer,
  "tag" integer,
  "identity" integer,
  PRIMARY KEY ("id"),
  CONSTRAINT "user_group" UNIQUE ("meritcommons_user", "grp"),
  CONSTRAINT "user_identity" UNIQUE ("meritcommons_user", "identity"),
  CONSTRAINT "user_role" UNIQUE ("meritcommons_user", "role"),
  CONSTRAINT "user_tag" UNIQUE ("meritcommons_user", "tag")
);
CREATE INDEX "meritcommons_user_assignment_idx_meritcommons_user" on "meritcommons_user_assignment" ("meritcommons_user");
CREATE INDEX "meritcommons_user_assignment_idx_grp" on "meritcommons_user_assignment" ("grp");
CREATE INDEX "meritcommons_user_assignment_idx_identity" on "meritcommons_user_assignment" ("identity");
CREATE INDEX "meritcommons_user_assignment_idx_role" on "meritcommons_user_assignment" ("role");

;
--
-- Table: meritcommons_user_profile_attribute_value.
--
CREATE TABLE "meritcommons_user_profile_attribute_value" (
  "id" serial NOT NULL,
  "create_time" integer NOT NULL,
  "modify_time" integer NOT NULL,
  "profile_attribute" integer NOT NULL,
  "user_attribute_value" integer NOT NULL,
  "ordinal" integer NOT NULL,
  PRIMARY KEY ("id")
);
CREATE INDEX "meritcommons_user_profile_attribute_value_idx_profile_attribute" on "meritcommons_user_profile_attribute_value" ("profile_attribute");
CREATE INDEX "meritcommons_user_profile_attribute_value_idx_user_attribute_value" on "meritcommons_user_profile_attribute_value" ("user_attribute_value");

;
--
-- Foreign Key Definitions
--

;
ALTER TABLE "meritcommons_stream" ADD CONSTRAINT "meritcommons_stream_fk_creator" FOREIGN KEY ("creator")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user" ADD CONSTRAINT "meritcommons_user_fk_notification_inbox" FOREIGN KEY ("notification_inbox")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user" ADD CONSTRAINT "meritcommons_user_fk_personal_inbox" FOREIGN KEY ("personal_inbox")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user" ADD CONSTRAINT "meritcommons_user_fk_personal_outbox" FOREIGN KEY ("personal_outbox")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link" ADD CONSTRAINT "meritcommons_link_fk_creator" FOREIGN KEY ("creator")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection" ADD CONSTRAINT "meritcommons_link_collection_fk_creator" FOREIGN KEY ("creator")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection" ADD CONSTRAINT "meritcommons_link_collection_fk_parent" FOREIGN KEY ("parent")
  REFERENCES "meritcommons_link_collection" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_localauth" ADD CONSTRAINT "meritcommons_localauth_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_session" ADD CONSTRAINT "meritcommons_session_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_author" ADD CONSTRAINT "meritcommons_stream_author_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_author" ADD CONSTRAINT "meritcommons_stream_author_fk_added_by" FOREIGN KEY ("added_by")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_author" ADD CONSTRAINT "meritcommons_stream_author_fk_stream" FOREIGN KEY ("stream")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message" ADD CONSTRAINT "meritcommons_stream_message_fk_regarding" FOREIGN KEY ("regarding")
  REFERENCES "meritcommons_stream_message" ("unique_id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message" ADD CONSTRAINT "meritcommons_stream_message_fk_in_reply_to" FOREIGN KEY ("in_reply_to")
  REFERENCES "meritcommons_stream_message" ("unique_id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message" ADD CONSTRAINT "meritcommons_stream_message_fk_submitter" FOREIGN KEY ("submitter")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_moderator" ADD CONSTRAINT "meritcommons_stream_moderator_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_moderator" ADD CONSTRAINT "meritcommons_stream_moderator_fk_added_by" FOREIGN KEY ("added_by")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_moderator" ADD CONSTRAINT "meritcommons_stream_moderator_fk_stream" FOREIGN KEY ("stream")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_subscriber" ADD CONSTRAINT "meritcommons_stream_subscriber_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_subscriber" ADD CONSTRAINT "meritcommons_stream_subscriber_fk_added_by" FOREIGN KEY ("added_by")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_subscriber" ADD CONSTRAINT "meritcommons_stream_subscriber_fk_stream" FOREIGN KEY ("stream")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_watcher" ADD CONSTRAINT "meritcommons_stream_watcher_fk_target" FOREIGN KEY ("target")
  REFERENCES "meritcommons_stream" ("unique_id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_watcher" ADD CONSTRAINT "meritcommons_stream_watcher_fk_watcher" FOREIGN KEY ("watcher")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_meritcommonscointransaction" ADD CONSTRAINT "meritcommons_user_meritcommonscointransaction_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_alias" ADD CONSTRAINT "meritcommons_user_alias_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_alias" ADD CONSTRAINT "meritcommons_user_alias_fk_owner" FOREIGN KEY ("owner")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_attribute" ADD CONSTRAINT "meritcommons_user_attribute_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_group" ADD CONSTRAINT "meritcommons_user_group_fk_owner" FOREIGN KEY ("owner")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_watcher" ADD CONSTRAINT "meritcommons_user_watcher_fk_target" FOREIGN KEY ("target")
  REFERENCES "meritcommons_user" ("unique_id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_watcher" ADD CONSTRAINT "meritcommons_user_watcher_fk_watcher" FOREIGN KEY ("watcher")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "ap_casserver_ticket" ADD CONSTRAINT "ap_casserver_ticket_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "ap_casserver_ticket" ADD CONSTRAINT "ap_casserver_ticket_fk_issued_by_ticket" FOREIGN KEY ("issued_by_ticket")
  REFERENCES "ap_casserver_ticket" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_session_attribute" ADD CONSTRAINT "meritcommons_session_attribute_fk_session" FOREIGN KEY ("session")
  REFERENCES "meritcommons_session" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_session_keystore" ADD CONSTRAINT "meritcommons_session_keystore_fk_session" FOREIGN KEY ("session")
  REFERENCES "meritcommons_session" ("id") ON DELETE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_attachment" ADD CONSTRAINT "meritcommons_stream_message_attachment_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_attachment" ADD CONSTRAINT "meritcommons_stream_message_attachment_fk_uploader" FOREIGN KEY ("uploader")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_gizmo" ADD CONSTRAINT "meritcommons_stream_message_gizmo_fk_author" FOREIGN KEY ("author")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_gizmo" ADD CONSTRAINT "meritcommons_stream_message_gizmo_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_info" ADD CONSTRAINT "meritcommons_stream_message_info_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_info" ADD CONSTRAINT "meritcommons_stream_message_info_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_tag" ADD CONSTRAINT "meritcommons_stream_message_tag_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_tag" ADD CONSTRAINT "meritcommons_stream_message_tag_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_vote" ADD CONSTRAINT "meritcommons_stream_message_vote_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_vote" ADD CONSTRAINT "meritcommons_stream_message_vote_fk_voter" FOREIGN KEY ("voter")
  REFERENCES "meritcommons_user" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_watcher" ADD CONSTRAINT "meritcommons_stream_message_watcher_fk_target" FOREIGN KEY ("target")
  REFERENCES "meritcommons_stream_message" ("unique_id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_message_watcher" ADD CONSTRAINT "meritcommons_stream_message_watcher_fk_watcher" FOREIGN KEY ("watcher")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_messagestream" ADD CONSTRAINT "meritcommons_stream_messagestream_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_messagestream" ADD CONSTRAINT "meritcommons_stream_messagestream_fk_stream" FOREIGN KEY ("stream")
  REFERENCES "meritcommons_stream" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_attribute_value" ADD CONSTRAINT "meritcommons_user_attribute_value_fk_attribute" FOREIGN KEY ("attribute")
  REFERENCES "meritcommons_user_attribute" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_click" ADD CONSTRAINT "meritcommons_link_click_fk_identity" FOREIGN KEY ("identity")
  REFERENCES "meritcommons_user_identity" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_click" ADD CONSTRAINT "meritcommons_link_click_fk_link" FOREIGN KEY ("link")
  REFERENCES "meritcommons_link" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection_member" ADD CONSTRAINT "meritcommons_link_collection_member_fk_collection" FOREIGN KEY ("collection")
  REFERENCES "meritcommons_link_collection" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection_member" ADD CONSTRAINT "meritcommons_link_collection_member_fk_link" FOREIGN KEY ("link")
  REFERENCES "meritcommons_link" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection_role" ADD CONSTRAINT "meritcommons_link_collection_role_fk_collection" FOREIGN KEY ("collection")
  REFERENCES "meritcommons_link_collection" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_link_collection_role" ADD CONSTRAINT "meritcommons_link_collection_role_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_session_attribute_value" ADD CONSTRAINT "meritcommons_session_attribute_value_fk_attribute" FOREIGN KEY ("attribute")
  REFERENCES "meritcommons_session_attribute" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_messagelink" ADD CONSTRAINT "meritcommons_stream_messagelink_fk_link" FOREIGN KEY ("link")
  REFERENCES "meritcommons_link" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_stream_messagelink" ADD CONSTRAINT "meritcommons_stream_messagelink_fk_message" FOREIGN KEY ("message")
  REFERENCES "meritcommons_stream_message" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_profile_attribute" ADD CONSTRAINT "meritcommons_user_profile_attribute_fk_standard_attribute" FOREIGN KEY ("standard_attribute")
  REFERENCES "meritcommons_profile_standard_attribute" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_profile_attribute" ADD CONSTRAINT "meritcommons_user_profile_attribute_fk_user_attribute" FOREIGN KEY ("user_attribute")
  REFERENCES "meritcommons_user_attribute" ("id") DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_meritcommons_user" FOREIGN KEY ("meritcommons_user")
  REFERENCES "meritcommons_user" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_grp" FOREIGN KEY ("grp")
  REFERENCES "meritcommons_user_group" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_identity" FOREIGN KEY ("identity")
  REFERENCES "meritcommons_user_identity" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_assignment" ADD CONSTRAINT "meritcommons_user_assignment_fk_role" FOREIGN KEY ("role")
  REFERENCES "meritcommons_user_role" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_profile_attribute_value" ADD CONSTRAINT "meritcommons_user_profile_attribute_value_fk_profile_attribute" FOREIGN KEY ("profile_attribute")
  REFERENCES "meritcommons_user_profile_attribute" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "meritcommons_user_profile_attribute_value" ADD CONSTRAINT "meritcommons_user_profile_attribute_value_fk_user_attribute_value" FOREIGN KEY ("user_attribute_value")
  REFERENCES "meritcommons_user_attribute_value" ("id") DEFERRABLE;

;
