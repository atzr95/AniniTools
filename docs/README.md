# AniniTools GitHub Pages Setup

This folder contains the support website for AniniTools, hosted via GitHub Pages.

## Files
- `index.html` - Main support page with features and FAQ
- `privacy.html` - English and Bahasa Malaysia policy. Each `<article>` holds one language as headings and paragraphs. Keep its visible words identical to `assets/privacy/en.txt` and `assets/privacy/ms.txt`; `test/privacy_choice_test.dart` checks this.
- `style.css` - Shared style for both pages (fonts: Doto for the LED sign, Atkinson Hyperlegible Next for text)
- `icon.png` - App icon, used as the page mark and favicon
- `fonts/` - Self-hosted Latin subsets of both fonts plus their OFL licenses. Do not link a font host: the pages then make no third-party requests.

## Setup Instructions

### 1. Enable GitHub Pages

1. Push this repository to GitHub
2. Go to your repository settings
3. Navigate to **Pages** section (under Code and automation)
4. Under **Source**, select **Deploy from a branch**
5. Under **Branch**, select `main` (or `master`) and `/docs` folder
6. Click **Save**

### 2. Access Your Site

After enabling, your site will be available at:
```
https://atzr95.github.io/AniniTools/
```

These are the existing project URLs. Local edits do not publish them.

### 3. Use in App Store Connect

When submitting your app to the App Store:

1. Go to **App Store Connect**
2. Navigate to your app
3. Under **App Information**
4. Add your GitHub Pages URL to:
   - **Support URL**: `https://atzr95.github.io/AniniTools/`
   - **Privacy Policy URL**: `https://atzr95.github.io/AniniTools/privacy.html`

## Customization

### Update Links
In `index.html`, update the GitHub link in the footer:
```html
<a href="https://github.com/atzr95/AniniTools">GitHub</a>
```

### Add More Pages
Simply create more HTML files in this folder and link to them from `index.html`.

### Custom Domain (Optional)
If you have a custom domain:
1. Add a `CNAME` file in this folder with your domain
2. Configure DNS settings with your domain provider
3. Update the Custom Domain setting in GitHub Pages

## Testing Locally

Open the HTML files directly in your browser to preview changes before pushing to GitHub.

## Notes

- Changes take a few minutes to appear after pushing to GitHub
- GitHub Pages is free for public repositories
- The site is automatically rebuilt when you push changes
- All pages are static HTML (no server-side processing)
