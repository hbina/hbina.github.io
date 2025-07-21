# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Hanif Bin Ariffin's personal website and blog (https://hbina.github.io), built with Hugo static site generator and deployed via GitHub Pages.

## Essential Commands

### Hugo Development
```bash
# Start development server with live reload
hugo server

# Build for production
hugo --minify

# Create new blog post
hugo new content/post-name.md
```

### Resume Management
```bash
# Work with JSON Resume (run from jsonresume/ directory)
cd jsonresume
npm install
npm run serve    # Serve resume locally
npm run render   # Generate resume.html
```

### Content Management
```bash
# All blog posts are in content/ directory
# Use the archetype template for consistency:
# - title, date, author: "Hanif Bin Ariffin", draft: true/false
```

## Architecture

### Hugo Site Structure
- **config.toml**: Site configuration (baseURL: https://hbina.github.io)
- **content/**: Markdown blog posts with front matter
- **layouts/_default/**: Custom minimal theme templates (list.html, single.html)
- **static/**: Static assets including code examples
- **archetypes/default.md**: Template for new content creation

### Dual Content System
1. **Hugo Blog**: Technical and philosophical writing in Markdown
2. **JSON Resume**: Structured resume data in jsonresume/resume.json using Stack Overflow theme

### Custom Theme Features
- Minimal design with gray background (#B3B3B3)
- 60% width, centered layout with 1000px minimum width
- Simple navigation structure
- Focus on readability and content

## Deployment

Automatic deployment via GitHub Actions on pushes to master:
- Uses peaceiris/actions-hugo@v2
- Builds with `hugo --minify`
- Deploys to GitHub Pages

## Content Guidelines

### Blog Posts
- Place in content/ directory as .md files
- Use front matter: title, date, author, draft status
- Topics range from technical programming to philosophical pieces
- Examples: consciousness, programming context, system design

### Resume Updates
- Edit jsonresume/resume.json for structured data
- Run npm commands to regenerate HTML/PDF versions
- Keep photo.jpg updated as needed

## Development Workflow

1. Create content with `hugo new content/filename.md`
2. Use `hugo server` for live preview during writing
3. Set `draft: false` when ready to publish
4. Commit and push to trigger automatic deployment
5. For resume changes, work in jsonresume/ directory and regenerate files