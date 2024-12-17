# DCV-Clients

Here you can find useful scripts to customize and distribute DCV client installers.

## MacOS

You can execute the installer with 

```bash
sudo bash install_dcv_client.sh
```

and select if you want to Install, Uninstall or Cancel.

![Captura de Tela 2024-12-17 às 13 15 26](https://github.com/user-attachments/assets/6375cd20-2559-464f-958a-249d2a1b0814)

If you want to execute it without interaction, you have the following options:
```bash
sudo bash install_dcv_client.sh -no-interaction=install
sudo bash install_dcv_client.sh -no-interaction=uninstall
```

To debug the installer, we offer the debug parameter:
```bash
sudo bash install_dcv_client.sh -debug
```

If there is a logo.png (must be PNG!) file together with the script, it will show the logo to the user. Is possible to embed the image into the installer executing

```bash
bash build_installer.sh
```

It will ask you the name of the company and will create the installer with the logo (install_dcv_client.sh code plus logo.png).

![Captura de Tela 2024-12-17 às 13 37 06](https://github.com/user-attachments/assets/e3df4c42-68a2-4c5e-b054-0d49af6e41ab)

Note: If you need to change the installer code, you need to edit install_dcv_client.sh and execute the build_installer.sh again. Is not safe to modify the script with the image embedded unless you know what you are doing.
