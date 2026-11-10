# EPS Assistant — reconstruction Flutter (v1.2.0)

Reconstruction de l'application Android d'origine (`dz.eps.assistant.eps_assistant`)
à partir de l'APK (assets, schéma SQLite, structure) et de la vidéo d'utilisation.

## Compiler l'APK gratuitement avec GitHub
1. Créez un dépôt GitHub et poussez **tout** ce dossier.
2. Onglet **Actions** → « Build APK » → *Run workflow* (ou push sur `main`).
3. Téléchargez l'artefact `EPS_Assistant_apk` (fichier `app-release.apk`) en fin d'exécution.

Le dossier `android/` n'est pas versionné : le workflow le génère
(`flutter create` + `scripts/patch_android.sh` : permissions, nom) puis construit l'APK.
Si le build échoue, copiez le message d'erreur du journal Actions.

## Structure
```
lib/
  main.dart            point d'entrée (onboarding → navigation)
  constants/           niveaux, périodes, statuts par défaut, listes d'incident
  models/              12 modèles (un par table SQLite)
  services/            SQLite, dépôts, PDF (HTML→PDF), sauvegarde ZIP, reset
  providers/           Riverpod (langue, thème, classes, élèves, emploi du temps…)
  screens/             écrans (emploi du temps, appel, classes, notes, clôture, fiches, incidents, paramètres)
  widgets/             feuilles modales, export, sélecteur de date
  themes/ utils/ routes/ animations/
assets/ images/ fonts/ (logo, icône, Arial) — repris tels quels de l'APK
```

## Ce qui est volontairement absent
- Système de licence (demande du propriétaire du projet).
- Verrouillage par code PIN (demande du propriétaire du projet).

## Limites connues (voir le rapport de livraison)
- Le code n'a pas pu être compilé ni exécuté dans l'environnement de conception.
- Écrans non reproduits faute de capture : historique des séances, statistiques de classe,
  matrice d'assiduité trimestrielle, menu ⋮ du planning (voir la liste dans le rapport).
