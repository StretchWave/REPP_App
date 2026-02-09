# Azure DevOps Wiki Integration Guide

This guide explains how to link your `FOUNDERS_LOG.md` to the Azure DevOps Wiki to ensure it's easily searchable and kept within your organization.

## 1. Initialize the Wiki (If not already done)
1.  Navigate to your Azure DevOps project.
2.  Click on **Overview** -> **Wiki**.
3.  Click **Create Wiki**.

## 2. Publish Code as Wiki
Instead of manually copying content, we will publish the `FOUNDERS_LOG.md` file directly from the repository. This ensures the Wiki is always up-to-date with the code.

1.  In the Wiki section, click on the **Publish code as wiki** option (or select "Publish code as wiki" from the top dropdown if a wiki already exists).
2.  **Select folder:** Choose the root folder `/` (or specifically select `FOUNDERS_LOG.md` if you want it as a single page, but mapping the root allows you to expose other docs too).
3.  **Wiki name:** Give it a name like "FoundersLog".
4.  **Publish**.

## 3. Searching the Log
*   Once published, you can use the **Search** bar at the top of Azure DevOps.
*   The content of `FOUNDERS_LOG.md` is now indexed and searchable by your future self and team members.

## 4. Intellectual Property & Security
*   By keeping the log as a file in the repo and publishing it to the internal Azure DevOps Wiki, all data remains within your Azure organization's security boundary.
*   Access is controlled by your Azure DevOps project permissions.
