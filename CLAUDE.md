## product.yaml rule

`product.yaml` in the repo root is the single source for the studio dashboard and for the legal pages on the website. When you finish a piece of work, update the file in the same session if any of these happened:

- A feature or fix was completed → add it to the top of `recent`; if the list exceeds 5 items, drop the oldest.
- The version number changed → update `versions.in_progress`.
- A dependency or third-party service was added or removed, or the data the app collects changed → update `legal.third_parties` and `legal.data_collected`, and tell me the legal pages need review.
- Store screenshots were produced or changed → update `marketing`.
- A plan was added, finished or cancelled → update `planned`.

Set `updated_at` to today's date on every update. Do not rename, reorder, add or remove fields. Never fill a field by guessing; leave it empty and ask me. Use only the fixed vocabulary for `legal.data_collected`. Change `status`, `versions.live` and `versions.in_review` only when I tell you to.
