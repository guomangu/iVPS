# **Stack d'Administration VPS : Zoraxy \+ Cockpit \+ SFTPGo**

Cette stack hybride (mixant installation native et conteneurs Podman) offre un équilibre parfait entre **sécurité**, **facilité d'utilisation** (interfaces web) et **puissance d'administration**.

## **1\. L'Architecture Globale (Le Flux)**

> 1. **Internet** frappe à la porte de votre serveur sur les ports 80 et 443 (HTTP/HTTPS).  
> 2. **Zoraxy** intercepte tout le trafic, chiffre les connexions (SSL) et vérifie les règles d'accès.  
> 3. En fonction de l'URL demandée, Zoraxy redirige le trafic vers la bonne cible :  
   * admin.votre-domaine.com ➔ **Cockpit** (pour gérer le système).  
   * fichiers.votre-domaine.com ➔ **SFTPGo** (pour gérer les données).  
   * app.votre-domaine.com ➔ N'importe quel autre conteneur Podman que vous hébergerez plus tard.

## **2\. Cockpit : La Tour de Contrôle (Installation Native)**

Contrairement aux autres outils, Cockpit s'installe **directement sur le système d'exploitation** de votre VPS (Debian, Ubuntu, AlmaLinux, etc.). Il s'allume à la demande via un socket Systemd, consommant littéralement 0 ressource quand vous n'êtes pas sur la page web.  
**Les modules Cockpit indispensables à installer :**

> * **cockpit-podman :** Le module roi de votre stack. Il vous permet de télécharger des images, de démarrer/arrêter vos conteneurs, de voir leur consommation CPU/RAM, et de lire leurs journaux (logs) en temps réel avec une belle interface graphique.  
> * **cockpit-storaged :** Gère vos disques. Permet de voir l'espace disponible, de formater de nouveaux disques, de gérer les partitions et de surveiller la santé (SMART) du stockage.  
> * **cockpit-pcp (Performance Co-Pilot) :** Active l'enregistrement des métriques. Vous pourrez voir l'historique de consommation CPU/RAM et Réseau de votre VPS sur plusieurs jours/semaines, et pas seulement en temps réel.  
> * **cockpit-packagekit :** Vous alerte lorsqu'il y a des mises à jour de sécurité pour votre OS et permet de les installer d'un simple clic.  
> * **Le Terminal intégré :** Un émulateur de terminal parfait, tournant avec vos droits utilisateur, idéal pour les tâches en ligne de commande (comme éditer un compose.yaml avec nano ou lancer un podman compose up).

## **3\. Zoraxy : Le Routeur & Vigile (Conteneur Podman)**

Zoraxy est votre **Reverse Proxy**. C'est le seul composant directement exposé à Internet (ports 80 et 443).

> * **Gestion centralisée des accès :** Si un service ne possède pas de système d'authentification fiable, vous pouvez utiliser Zoraxy pour exiger un mot de passe avant même d'afficher la page.  
> * **Certificats SSL automatisés :** Zoraxy gère Let's Encrypt de manière transparente. Toutes vos interfaces (Cockpit, SFTPGo) bénéficient d'une connexion HTTPS sécurisée (le petit cadenas).  
> * **WAF (Web Application Firewall) intégré :** Il protège votre serveur contre les requêtes malveillantes, les scanners de vulnérabilités, et permet de bannir des pays entiers ou des IP agressives.  
> * **Routage réseau facile :** Son interface graphique très intuitive permet de router un sous-domaine vers un port spécifique en 3 clics.

## **4\. SFTPGo : La Gare de Triage des Fichiers (Conteneur Podman)**

SFTPGo vient remplacer les solutions vieillissantes et complexes. Il gère vos fichiers avec une robustesse professionnelle.

> * **L'Interface Web Client :** Un explorateur de fichiers magnifique directement dans votre navigateur. Vous pouvez uploader, télécharger, renommer ou déplacer des fichiers facilement, parfait pour ajuster rapidement une configuration.  
> * **Le Protocole SFTP :** Expose le port 2022 (par exemple) sur votre VPS. Cela vous permet d'utiliser des logiciels professionnels depuis votre ordinateur local (comme FileZilla, Cyberduck, ou l'extension SFTP/SSH de VS Code) pour travailler sur vos fichiers comme s'ils étaient sur votre machine.  
> * **Chroot & Sécurité :** Vous pouvez créer des utilisateurs virtuels dans SFTPGo (sans créer d'utilisateurs Linux sur le VPS). Vous pouvez enfermer un utilisateur dans un dossier spécifique (par exemple, un utilisateur "dev" qui n'a accès qu'au dossier /vps-data/site-web).

## **Synthèse du Workflow Quotidien**

> 1. Vous codez ou téléchargez une nouvelle application.  
> 2. Vous utilisez **SFTPGo** pour glisser-déposer les fichiers et le compose.yaml de l'application sur le serveur.  
> 3. Vous ouvrez **Cockpit**, lancez le terminal web, et tapez podman compose up \-d. (Ou vous le faites via l'interface de cockpit-podman).  
> 4. Vous allez sur **Zoraxy** pour lier nouvelle-app.votre-domaine.com au conteneur fraîchement démarré.  
> 5. C'est en ligne, sécurisé, et monitoré \!