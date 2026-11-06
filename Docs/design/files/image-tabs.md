# Image tabs

What an image's file tab shows and why each went the way it did. Newest at the
bottom.

- **A file whose name types it as an image ImageIO decodes opens in a tab and is
  drawn**: PNG, JPEG, GIF, HEIC, WebP, TIFF, ICO, PSD and camera raw among them.
  Text wins, so an SVG, typed as both and read by no ImageIO, opens as text, and
  a `.png` holding text reads as text. Bytes that decode as no image are read as
  any other file, a binary notice or rows. A PDF is no image here.
- **An image tab draws the committed copy beside the file where their bytes
  differ**, captioned Before and After with each one's pixels and size, the
  committed copy being `HEAD`'s, or the merge base's under Branch, as rows
  count. One copy alone is uncaptioned by side: a new or unchanged file, or a
  deleted one's committed copy, struck. A file deleted under an open tab keeps
  the copy it last showed, as text does. No pixel diff, no Unified or Split, no
  arrows or find; the command line refuses a step or find on one.
- **An image is capped at 32 MiB a copy, against text's 1 MiB**: the text cap is
  TextKit's layout, and a picture's cost is its pixels, not its file. The view
  decodes at most 3,072 pixels on the longest side, 36 MB, off the main thread,
  turned by its orientation, and draws a point to a pixel, scaled down to fit
  and never up. The model keeps the bytes, so a hidden tab lets them go as it
  does rows and reads them again when shown, a deleted file's committed copy
  included; the last copy on disk of a file deleted under its tab is kept, as
  its text would be. A git read that fails keeps the last committed copy beside
  the file as read, as rows are kept. A read asks git for the committed copy's
  object id and reads the copy whole, by that id, only where that moved, and
  keeps the last read's buffers where the bytes match, a copy matching the file
  sharing its buffer, so the main actor's comparison of two readings reads no
  bytes: 64 MiB compared took 1.8 ms, and a shared buffer none. Cost: a
  committed copy past the cap or not an image is left out, so the tab draws one
  copy while its dot says modified; a GIF draws its first frame; there is no
  checkerboard behind transparency; a picture cut short past its header draws an
  empty box, ImageIO calling it complete until decoded; and a Git LFS file's
  committed copy is its pointer, read raw as `git diff` reads it, so it draws
  one copy. A 16-bit or HDR picture is drawn again at 8 bits a channel, keeping
  the 36 MB. ImageIO's peak while it scales grows with that cap, not the file: a
  48-megapixel photo peaked at 130 MB at 3,072 and 430 MB at 4,096, and a
  16,000-pixel square PNG of 4 MB at 161 and 403.
- **An image tab takes no find bar**: Cmd+F and the menu's Find find nothing to
  target there, where a notice keeps its bar for rows a later read may bring. A
  find opened before the image was read ends when it is.
- **Decodes run one at a time on a queue of their own**, as the 3,072 cap holds
  the peak for one only, and a decode whose bytes a newer read replaced before
  its turn is skipped; one already running is not stopped.
- **An image or a notice takes the keyboard through a view behind it**, so a
  click there focuses its tab and group and a reconcile's hand-off lands, as a
  text view's does; the pictures and words let clicks through to it. Keys typed
  there do nothing.

## Reviewed and left as is

Raised by reviews and settled; a review need not raise these again.

- **A deleted image whose committed copy is no image reads that copy twice**
  (2026-11-06 review), once as an image and once by `git diff` for its removed
  lines. It takes an image's name, a committed copy that is not one and the file
  gone; keeping the bytes for the diff would mean a second way to diff.
- **An image read asks `rev-parse` for the copy's id beside the `cat-file -s`
  that sized it** (2026-11-06 review): one process more a read, about 3 ms,
  against changing the size read every text tab shares.
- **A multi-image file is read at index 0, not its primary image** (2026-11-06
  review), unproven: an ICO lists its largest entry first, and a HEIC written
  with another primary still read 0 as primary here.
- **An image read loads the file whole though it has not changed** (2026-11-06
  review), a git change or a scope switch reading every tab again: the reads are
  paced at ten times their cost, as text tabs are, so a 25 MB photo's 10 ms
  reads at most every 100 ms, and a signature check would be a second way to
  tell a file unchanged beside the one the watch already keeps.
- **Images share `FileTabReader.read` with text up to the committed side**
  (2026-11-06 review): both resolve the side, the merge base and the gone file's
  kept reading the same way, and a reader of their own would repeat those.
- **Under Branch, a git read that fails right after a scope switch keeps the
  last committed image** (2026-11-06 review), which may be `HEAD`'s captioned
  Before: rows keep the other scope's text the same way, under Costs left under
  Branch in files/modified-and-branch.md, and the next read puts it right.
- **An image's name with bytes no decoder reads is read whole on each read**, up
  to 32 MiB, to say it is too large (2026-11-06 review): its name is all that
  says image before the bytes are in hand, and such a file is rare.
- **`debug memory` says `contentMemory` where it said `textMemory`** (2026-11-06
  review): a debug reading the app's own scripts do not parse, and the old name
  would say text of image bytes.
