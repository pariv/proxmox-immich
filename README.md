# immich Proxmox VE Helper Script
This repository is solely intended to create a new immich helper script that automates native LXC install on Proxmox. I hope that one day it can be incorporated in the tteck repository.

Use of the script can be done by pasting in the Proxmox shell:

`bash -c "$(wget -qLO - https://github.com/pariv/proxmox-immich/raw/main/ct/immich.sh)"`

This script is under development and not fully tested.
It takes a long time to install!

<div align="center">
  <a href="#">
    <img src="https://raw.githubusercontent.com/tteck/Proxmox/main/misc/images/logo.png" height="100px" />
 </a>
</div>
<h1 align="center">Proxmox VE Helper-Scripts</h1>

<p align="center">
  <a href="https://helper-scripts.com">Website</a> | 
  <a href="https://github.com/tteck/Proxmox/blob/main/.github/CONTRIBUTING.md">Contribute</a> |
  <a href="https://github.com/tteck/Proxmox/blob/main/USER_SUBMITTED_GUIDES.md">Guides</a> |
  <a href="https://github.com/tteck/Proxmox/blob/main/CHANGELOG.md">Changelog</a> |
  <a href="https://ko-fi.com/D1D7EP4GF">Support</a>
</p>

---

> [!WARNING]
Be cautious of copycat or coat-tailing sites that exploit the project's popularity with potentially malicious intent. Please only trust information from https://Helper-Scripts.com/ or https://tteck.github.io/Proxmox/.

These scripts empower users to create a Linux container or virtual machine interactively, providing choices for both simple and advanced configurations. The basic setup adheres to default settings, while the advanced setup gives users the ability to customize these defaults. 

Options are displayed to users in a dialog box format. Once the user makes their selections, the script collects and validates their input to generate the final configuration for the container or virtual machine.
<p align="center">
Be cautious and thoroughly evaluate scripts and automation tasks obtained from external sources. <a href="https://github.com/tteck/Proxmox/blob/main/CODE-AUDIT.md">Read more</a>
</p>
<sub><div align="center"> Proxmox® is a registered trademark of Proxmox Server Solutions GmbH. </div></sub>
