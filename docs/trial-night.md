# Trial night — dry run

Drive this yourself, start to finish, before the coach ever touches it. It
follows one imaginary night in order, the way she will actually use it.

Anywhere you see **STOP**, something is wrong and worth reporting rather than
working around — that is the whole point of doing this on a Tuesday instead of
on game night.

Use your own account, not the throwaway one. Roughly 20 minutes.

---

## 0. Before you start

- [ ] Open https://badminton-ph.web.app and hard-refresh once (Ctrl+Shift+R).
- [ ] Chrome offers **Install app** in the address bar — install it. A tab can
      be closed by accident, and browsers can evict site storage; the installed
      app is what she should use on the night.
- [ ] The tab icon is a green shuttlecock, not the Flutter logo.

## 1. Sign in

- [ ] Sign in normally. Your browser offers to **save the password** — if it
      does not, the autofill wiring has regressed. **STOP.**
- [ ] Sign out. It asks first, and says signing back in needs internet. Cancel.
- [ ] Sign out for real, then sign back in. The saved password is offered.
- [ ] Type a wrong password five times. On the fifth, the button becomes
      **Try again in 15 seconds** and counts down.
- [ ] Tap **Forgot your password?** with your email filled in. You get the same
      neutral message either way, and the reset email actually arrives.

## 2. The dashboard

- [ ] Your name is in the green header.
- [ ] **Regulars** shows a count. Tap it — the regulars book opens.
- [ ] **Carried over** shows what players still owe you from past nights.
      Zero is correct if nobody owes you.
- [ ] If your GCash number vanished at any point, check the Money tab later in
      this run — it should have repaired itself.

## 3. Create the night

- [ ] **New session**. Title it something real, set tonight's date, 2 courts,
      a court fee you recognise (say ₱1,200), shuttle price, per-head.
- [ ] It appears immediately, and does **not** disappear a second later.
      **STOP** if it does.
- [ ] Back on the dashboard it sits at the top under **TONIGHT**, with a big
      **Open tonight** button.

## 4. Import a messy roster

Paste this exactly — it is deliberately awful, and every line is a real
pattern from a group chat:

```
Thursday July 06 8pm Yspacio
Confirmed players:
1. Mark
2. Ana - paid
3. Kuya Jun (bringing a friend later tonight) +1
4. jun
5. Niña ok
6. Rica +1
7. Mark Anthony (late, might come after work)
8. Paolo confirmed
sana all makalaro 😂
```

- [ ] The header, the "Confirmed players:" line and the "sana all" line are
      **skipped but still shown**, so you can rescue anything wrongly dropped.
- [ ] **Ana**, **Niña**, **Paolo** come through with their names clean — the
      "paid" / "ok" / "confirmed" markers stripped, not the names.
- [ ] **Mark Anthony** survives despite the long note. **STOP** if he is gone.
- [ ] **Kuya Jun** appears *and* so does his guest. Same for Rica.
- [ ] **Jun** and **jun** are both kept, and flagged as possible duplicates.
      They are never merged — two real people share that name in a big club.
- [ ] Set skill tiers on a few players, then save.

## 5. Run some games

- [ ] Courts tab → **Next match**. Four players are suggested; you can swap any
      of them before starting.
- [ ] Start it. The session chip flips to **Live** on its own, and the
      dashboard hero now says **Resume the night**.
- [ ] Tap a player on a court to substitute someone from the queue.
- [ ] End the match. Those players' game counts go up, their wait resets, and
      the queue re-sorts so the longest-waiting are next.
- [ ] Run three or four more so the fairness spread is visible. Nobody should
      be two games ahead of anyone else.
- [ ] Add a late arrival mid-session. They join on the current minimum game
      count — not zero — so they do not jump the whole queue.

## 6. The offline drill — the one that matters

This is the acceptance test. A four-hour night at the gym is the real
environment, not your desk.

- [ ] Turn off wifi and mobile data **completely**.
- [ ] Start a match, end it, add a player, edit a name, mark someone paid.
- [ ] Everything responds instantly. Nothing spins. **STOP** if anything hangs
      — that is the exact failure that would kill a real night.
- [ ] A "not yet synced" indicator is visible.
- [ ] Turn the network back on. The indicator clears and the data is in the
      Firebase console.

## 7. Money

- [ ] Money tab. The total splits correctly — ₱1,200 across 9 players is
      ₱133.34 for three of them and ₱133.33 for six. The parts sum to exactly
      ₱1,200, never ₱1,199.99.
- [ ] Your GCash number is shown. If it is missing, add it once.
- [ ] **Lock the amounts.**
- [ ] Now go add another player to the roster, then come back. **The locked
      amounts have not moved.** **STOP** if they changed — someone who already
      paid would be owed a refund.
- [ ] Mark a few as paid. The collected total tracks.
- [ ] **Share summary** produces text you would actually paste into the group
      chat.

## 8. Recap and the board

- [ ] Recap tab: per-player games, partners, longest wait. Anyone who never got
      on court is shown in red rather than hidden.
- [ ] No skill tiers anywhere in the recap or its share text — it gets pasted
      into the group chat, and "Ben — Beginner" is a bad night for Ben.
- [ ] The TV icon opens the Up Next board. Leave it open a minute; the screen
      does not sleep.

## 9. Insurance

- [ ] The save icon exports the whole night as plain text. Read it — could you
      rebuild the night from this alone if the phone died? That is its job.

---

## After the run

Three things only the coach can answer, and each one blocks something:

1. **Which rotation format does the club actually play?** Straight fair
   rotation is built. Winner-stays and king-of-court are not, on purpose.
2. **Do early leavers still pay their full share?** The app currently says yes.
3. **Does she want her GCash QR on the bill**, or is the number enough?

And the one thing that would most improve the import: two or three **real**
pastes from the club's group chat. Every parser bug so far was found by using a
real-looking list, and the guesses were wrong twice.
