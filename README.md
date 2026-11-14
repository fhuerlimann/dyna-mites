# Dyna-Mites

**Small bugs. Big bangs.**

A turn-based artillery game for the browser. Teams of tiny mites take turns lobbing explosives across destructible terrain in several worlds, including Sugarland, a world made of cake and candy.

## Play

Open `index.html` in any modern browser. Everything is in one file, with no build step and no dependencies.

- **Desktop:** arrow keys move and aim, Space fires, and you click the map to mark targets.
- **Mobile:** play in landscape. Drag on the map to aim, and use the on-screen buttons to move, jump and fire. Pinch to zoom.

Play it at **https://fhuerlimann.github.io/dyna-mites/**.

## Online play

Click **Play a friend online** and send your friend the invite link. Moves arrive live when you're both online; otherwise each of you takes your turn whenever you like. The menu shows how many players are online right now.

Online play runs on [Supabase](https://supabase.com): every player is an anonymous guest, and database rules let only the two players in a match change it. The setup SQL is in [`supabase/schema.sql`](supabase/schema.sql). The key in `index.html` is Supabase's publishable key, which is meant to be public.

When the game is opened as a claude.ai artifact, it uses claude.ai's own storage for friend games instead.
