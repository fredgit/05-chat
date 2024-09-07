-- Add migration script here
-- if chat changed, notify with chat data
CREATE OR REPLACE FUNCTION add_to_chat()
  RETURNS TRIGGER
  AS $$
BEGIN
  -- a log for notice -> INFO sqlx::postgres::notice: add_to_chat: (6,1,abc,private_channel,"{1,2}","2024-09-07 10:03:12.877627+00")
  RAISE NOTICE 'add_to_chat: %', NEW;
  PERFORM
    -- a log for pg_notify -> INFO notify_server::notif: Received notification: PgNotification { process_id: 70027, channel: "chat_updated", payload: "{\"op\" : \"INSERT\", \"old\" : null, \"new\" : {\"id\":6,\"ws_id\":1,\"name\":\"abc\",\"type\":\"private_channel\",\"members\":[1,2],\"created_at\":\"2024-09-07T10:03:12.877627+00:00\"}}" }
    pg_notify('chat_updated', json_build_object('op', TG_OP, 'old', OLD, 'new', NEW)::text);
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER add_to_chat_trigger
  AFTER INSERT OR UPDATE OR DELETE ON chats
  FOR EACH ROW
  EXECUTE FUNCTION add_to_chat();

-- if new message added, notify with message data
CREATE OR REPLACE FUNCTION add_to_message()
  RETURNS TRIGGER
  AS $$
DECLARE
  USERS bigint[];
BEGIN
  IF TG_OP = 'INSERT' THEN
    RAISE NOTICE 'add_to_message: %', NEW;
    -- select chat with chat_id in NEW
    SELECT
      members INTO USERS
    FROM
      chats
    WHERE
      id = NEW.chat_id;
    PERFORM
      pg_notify('chat_message_created', json_build_object('message', NEW, 'members', USERS)::text);
  END IF;
  RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER add_to_message_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION add_to_message();
