You are a security analyst helping me in my reconnaissance approach. I have authorization to test this target. Attach the output from one tool to another (subfinder → httpx → naabu → katana): a list of subdomains, live hosts, open ports, and crawled URLs.


my target is mtnonline.com

Do not exploit anything or write exploit payloads — your job is to help me prioritize where a human should look first.

Before analyzing, mentally clean the data: ignore out-of-scope third-party hosts (Google, Twitter, Facebook, CDNs, font providers, etc.), collapse duplicate parameterized URLs into one representative entry (e.g. treat `page.php?id=1`, `?id=2`, `?id=3` as a single `page.php?[id]`), and set aside static assets (.css, .js, images, fonts) unless a filename itself looks sensitive.

Then give me a concise markdown report with these sections:

1. **Attack surface overview** — 2-3 sentences on what this target looks like.
2. **Notable open ports** — flag anything unusual or worth verifying. Note when a port set looks like a shared-host/CDN/mail-provider artifact rather than real per-host services.
3. **Interesting endpoints** — rank the most investigation-worthy paths and explain *why* (parameterized endpoints, auth/login/dashboard areas, upload or processing scripts, API-like paths, admin/config/backup hints). Group related ones.
4. **Suggested next checks** — high-level, non-destructive verification steps, conceptual not copy-paste payloads.
5. **Likely false positives / noise.**

Be specific to my actual data — don't invent endpoints that aren't in the files.