# 🪽 Prototype Anything with Goose AI 🪿💨

> [!IMPORTANT]
> This template is centrally managed by CI/CD in the [coder/templates](https://github.com/coder/templates) repository.

This template creates an EC2 VM-based workspace that lets you quickly prototype *anything* using Goose AI inside a Coder workspace. Just tell Goose what you want to build, and it will generate code, run a development server, and show you a live "preview—all" automatically.

**NOTE**: Currently, task reporting is disabled as Coder's MCP server causes intermittent issues. This template will not report tasks back to your dashboard.

## ✍️ How to use

1. Create a **new workspace** using the **“Building with Goose AI”** template.
2. Fill out:
   - **Workspace Name** → (use a name or accept the suggestion)
   - **AI System Prompt** → describe global settings and parameters you want Goose AI to follow.
   - **AI Task Prompt** → describe what you want Goose AI to build.
3. Click **Create Workspace**.

🎉 That’s it! Your workspace will launch, and Goose AI will start building.

---

## 💡 Prompt examples

✅ “Build a simple hello world website.”  
✅ “Create an online sock store app with a product page”  
✅ “Make a website celebrating upcoming holidays with a festive design.”

You can also leave the prompt blank—Goose AI will ask you what to build after the workspace launches.

---

Your app will run on **port 3000** (accessible via Coder’s preview link). You can send additional instructions inside the workspace terminal to keep improving your project.