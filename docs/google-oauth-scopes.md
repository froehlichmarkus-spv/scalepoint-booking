# Google OAuth scopes

New Calendar and Meet connects request this set. Sign-in is unchanged: `openid`, `email`, and `profile` (`lib/tymeslot/auth/oauth/providers.ex`). A token that already carries `https://www.googleapis.com/auth/calendar` keeps working, because that grant includes every calendar call below. `include_granted_scopes=true` on the consent URL keeps scopes the account already approved and adds only what is missing.

Checked against the Calendar API v3 discovery document (`calendar.events.insert`, `patch`, `update`, `delete`, `get`, `list`, `move`, `instances`, `watch`, `calendar.calendarList.list`, `calendar.channels.stop`) on 26 November 2026. Each of those methods lists `https://www.googleapis.com/auth/calendar.events` or `https://www.googleapis.com/auth/calendar.calendarlist.readonly` among its accepted scopes. `channels.stop` and `events.watch` do not need the broad calendar grant.

## `openid`

Google returns an id token only when `openid` is requested. The callback reads `sub` from that token so a reconnect stays on the same Google account instead of attaching a second one.

## `email`

The same id token and the userinfo response carry the account address. It is what the dashboard shows for the connected calendar and what a reconnect sends as `login_hint`.

## `profile`

Sign-in asks for `profile` together with `openid` and `email`. Calendar and Meet connects do not add it. Nothing in the calendar calls reads a profile field, so the connect URL leaves this scope as the sign-in flow already set it.

## `https://www.googleapis.com/auth/calendar.events`

Creating, changing, moving and deleting events (`events.insert`, `events.patch`, `events.update`, `events.delete`, `events.move`) require an event-write scope. Reading events, listing instances and opening an `events.watch` channel accept this scope as well. It is the narrowest scope that covers those writes. The broad `https://www.googleapis.com/auth/calendar` scope also covers them, which is why an already connected account does not have to consent again until a call reports that a scope is missing.

## `https://www.googleapis.com/auth/calendar.calendarlist.readonly`

`calendarList.list` is how the app learns which calendars the account can see. The discovery document allows this readonly scope for that method. It does not allow creating or deleting calendars. `channels.stop` also accepts it, so stopping a push channel does not need a wider grant.

## `https://www.googleapis.com/auth/meetings.space.created`

Google Meet rooms are created with `spaces.create` and an in-progress call is ended with `spaces.endActiveConference`. Google documents `meetings.space.created` as the scope for spaces this app creates. The connect URL keeps it beside the two calendar scopes. A token that only has the old calendar grant and not this Meet scope is asked to reconnect; the call returns an error and the integration is flagged, it does not crash.
