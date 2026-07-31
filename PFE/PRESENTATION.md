# Carthage Transfer — Documentation du Projet

---

## Titre du Projet

**Carthage Transfer** — Plateforme de Transport de Luxe avec Gestion Intelligente des Réservations

---

## Description du Projet

Application mobile Flutter full-stack de réservation de transferts privés de luxe en Tunisie. Elle connecte clients et flotte haut de gamme (Standard, VIP, Luxe, Van) via une API REST FastAPI/MongoDB, un moteur de tarification dynamique et un assistant IA conversationnel (AVA).

---

## Problématique

Le secteur du transport privé en Tunisie souffre d'une absence de solution numérique unifiée : les réservations se font majoritairement par téléphone, les tarifs sont opaques et non standardisés, et le suivi des courses est inexistant pour le client. Les entreprises de transport peinent à piloter leur flotte, à fidéliser leur clientèle et à analyser leurs performances faute d'outils adaptés.

Carthage Transfer répond à cette problématique en proposant une plateforme complète qui digitalise l'ensemble du parcours : de la réservation en ligne avec tarification transparente et dynamique, jusqu'au suivi en temps réel du trajet, en passant par un programme de fidélité et un assistant IA capable de gérer réservations, réclamations et recommandations en langage naturel — supprimant les frictions pour le client et offrant à l'opérateur une visibilité totale sur ses opérations.

---

## Les Fonctionnalités

### 1. Gestion des Comptes & Profil Utilisateur
**Description :** Système d'inscription et de connexion sécurisé par JWT. Les utilisateurs peuvent créer un compte client, se connecter et réinitialiser leur mot de passe. Une fois connectés, ils accèdent à leur espace profil pour modifier leurs informations personnelles (nom, email, téléphone), uploader une photo de profil, choisir la langue de l'interface (Français / Anglais) et basculer entre le thème clair et sombre. La session et les préférences sont persistées localement via SharedPreferences et synchronisées côté serveur.

---

### 2. Réservation de Transport
**Description :** Flux de réservation complet permettant à un client de saisir un lieu de départ et d'arrivée (autocomplétion Google Places), de choisir une date et une heure, de consulter le trajet sur une carte interactive (Google Directions), de sélectionner un véhicule parmi une flotte réelle de 8 catégories (Economy, Comfort Sedan, Minivan, Large Van, Minibus, Classe E, Classe S, Classe V) et de confirmer sa réservation. Le mode de paiement (espèces ou carte) est choisi juste avant la confirmation finale.

---

### 3. Moteur de Tarification Dynamique
**Description :** Calcul automatique du prix basé sur la distance réelle (Google Directions API) et une grille tarifaire par véhicule (frais initial, tarif au kilomètre, tarif horaire, points d'arrêt), à laquelle s'ajoutent des surcharges configurables : supplément de nuit, supplément week-end, tarification de dernière minute et variations saisonnières. Les tarifs par véhicule et les règles de surcharge sont modifiables en temps réel par l'administrateur depuis un éditeur dédié dans le back-office, qui conserve un historique des changements de prix.

---

### 3bis. Paiement et Approbation
**Description :** Le client choisit entre paiement en espèces (à l'arrivée) et paiement par carte. Le paiement en espèces déclenche une réservation « en attente d'approbation » et notifie l'ensemble des administrateurs ; l'administrateur approuve depuis le tableau de bord (section dédiée aux approbations en attente), ce qui confirme la réservation et notifie le client. Le paiement par carte est actuellement présenté comme une option « bientôt disponible » et redirige vers le paiement en espèces — aucune passerelle de paiement réelle n'est intégrée à ce stade.

---

### 4. Promotions & Programme de Fidélité
**Description :** Système double couche de valorisation client. D'un côté, validation de codes promo lors de la réservation (ex. WELCOME10, CDHC5, CDHC10) avec application automatique d'un pourcentage de réduction sur le prix final. De l'autre, un programme de points de récompense attribués après chaque trajet effectué, consultables depuis le profil et échangeables contre des avantages ou réductions. L'administrateur gère la création, la modification et la désactivation des promotions et des niveaux de fidélité depuis le tableau de bord.

---

### 5. Historique & Suivi des Trajets
**Description :** Les clients accèdent à la liste de leurs réservations passées et à venir. Chaque trajet affiche son statut en temps réel (En attente, Confirmé, En cours, Terminé, Annulé). Les modifications de réservation sont soumises à une règle de délai minimum (24 heures avant le départ).

---

### 6. Tableau de Bord & Analyses Administrateur
**Description :** Interface d'administration complète réunissant la gestion opérationnelle et l'analytique. L'administrateur peut visualiser, modifier et changer le statut de toutes les réservations, approuver les paiements en espèces en attente, piloter la flotte de véhicules et gérer les réclamations clients. Le tableau de bord analytique intégré affiche les métriques clés : revenus totaux, nombre de trajets par période, routes les plus demandées et réclamations ouvertes, permettant d'optimiser les opérations et d'identifier les tendances.

---

### 6bis. Gestion des Réclamations
**Description :** Les clients peuvent soumettre une réclamation (directement ou via l'assistant AVA). L'administrateur consulte la liste des réclamations, filtre par statut (ouverte / en cours d'examen / résolue) et met à jour leur statut depuis une fiche détaillée. Le tableau de bord affiche le nombre de réclamations ouvertes en temps réel.

---

### 7. Gestion de la Flotte de Véhicules
**Description :** L'administrateur peut ajouter, modifier et supprimer des véhicules depuis le back-office. Chaque véhicule possède une catégorie, une capacité, une description et un tarif de base. Les clients visualisent la flotte disponible avec photos et caractéristiques avant de sélectionner leur véhicule.

---

### 8. Gestion des Fournisseurs (Suppliers)
**Description :** Module back-end complet (API + écran d'administration) permettant de gérer les partenaires et sous-traitants de transport associés à la plateforme (création, consultation, mise à jour, changement de statut). *Note d'implémentation : l'écran existe mais n'est pas encore relié à la navigation du tableau de bord — fonctionnalité prête côté serveur, non accessible dans l'application en l'état actuel.*

---

### 9. Lieux Favoris
**Description :** Les utilisateurs peuvent sauvegarder leurs adresses fréquentes (domicile, bureau, aéroport…) pour accélérer la saisie lors des réservations suivantes. Les favoris sont synchronisés avec le serveur et accessibles depuis n'importe quel appareil.

---

### 10. Guide des Destinations Touristiques
**Description :** Section de découverte permettant aux voyageurs de consulter des recommandations personnalisées sur les destinations tunisiennes : restaurants, hôtels et activités culturelles. Chaque destination propose une fiche détaillée avec description et catégorisation.

---

### 11. Assistant IA Conversationnel & Vocal (AVA)
**Description :** Agent conversationnel intelligent construit sur une architecture LangChain + LangGraph avec pipeline RAG (Retrieval-Augmented Generation) et un ensemble d'outils IA actionnables. AVA agit comme un agent autonome capable de comprendre l'intention de l'utilisateur et d'exécuter des actions concrètes dans la plateforme.

**Capacités de l'agent :**

- **Support client & Politique de l'entreprise** — AVA interroge une base de connaissances vectorielle (politique tarifaire, CGU, procédures) via RAG pour répondre avec précision aux questions des clients, agissant comme un agent de support 24/7.
- **Recommandations Promotions & Fidélité** — L'agent analyse le profil et l'historique du client pour suggérer proactivement les codes promo applicables et les avantages du programme de récompenses adaptés à sa situation.
- **Recommandation de Véhicules** — Basée sur les préférences déclarées, le nombre de passagers, le type de trajet et l'historique de réservations, AVA propose la catégorie de véhicule la plus adaptée (Standard, VIP, Luxe, Van).
- **Réservation Assistée** — L'agent peut initier et compléter une réservation complète en langage naturel, en pré-remplissant les champs (lieu, date, véhicule) depuis le profil et les préférences de l'utilisateur.
- **Gestion des Trajets par Commande Vocale** — L'utilisateur peut consulter ses prochains voyages, modifier les détails d'une réservation ou l'annuler entièrement via des commandes vocales traitées en temps réel par le pipeline de reconnaissance vocale.
- **Assistance Réclamations & Feedback** — AVA guide le client dans la formulation d'un feedback ou d'une réclamation structurée, puis transmet automatiquement le rapport à l'administration via l'API interne, sans que le client ait à naviguer dans les formulaires.
- **Analyse Métier pour l'Administrateur (Business Intelligence)** — Côté administrateur, AVA peut produire à la demande une analyse complète de l'activité (revenus par mois et par catégorie de véhicule, volume de réservations, impact des changements tarifaires) sous forme de graphiques interactifs et d'un résumé rédigé, en interrogeant directement la base de données de production.

**Sécurité et fiabilité :** chaque action d'écriture proposée par AVA (créer, modifier, annuler une réservation ; modifier un tarif) passe par une étape de confirmation explicite avant exécution ; les outils accessibles sont strictement séparés selon le rôle (client / administrateur) ; toute action administrateur est journalisée. En cas d'indisponibilité du modèle de langage (quota atteint), l'assistant affiche un message clair plutôt qu'une erreur technique.



## Technologies Utilisées

### Frontend — Application Mobile

| Technologie | Rôle |
|---|---|
| **Flutter 3.3+** | Framework de développement mobile cross-platform |
| **Dart** | Langage de programmation Flutter |
| **Material Design 3** | Système de design UI/UX |
| **Google Fonts** | Typographie (Montserrat, etc.) |
| **HTTP** | Client HTTP pour les appels API REST |
| **SharedPreferences** | Persistance locale (session, préférences) |
| **Image Picker** | Sélection et upload de photos de profil |
| **Intl** | Internationalisation et formatage des dates |
| **Google Maps Flutter** | Carte, autocomplétion de lieux (Places) et tracé d'itinéraire (Directions) |
| **Speech-to-Text** | Reconnaissance vocale pour les commandes vocales AVA |
| **fl_chart** | Graphiques (ligne/aire/barres/camembert) du tableau de bord analytique AVA |

### Backend — API REST

| Technologie | Rôle |
|---|---|
| **Python 3.11+** | Langage de programmation backend |
| **FastAPI** | Framework web asynchrone pour l'API REST |
| **Uvicorn** | Serveur ASGI pour FastAPI |
| **Pydantic v2** | Validation des données et schémas DTOs |
| **pydantic-settings** | Gestion de la configuration par variables d'environnement |
| **JWT (python-jose)** | Authentification stateless par token |
| **Passlib / bcrypt** | Hachage sécurisé des mots de passe |
| **python-multipart** | Gestion des uploads de fichiers |

### Base de Données

| Technologie | Rôle |
|---|---|
| **MongoDB 7** | Base de données NoSQL orientée documents |
| **Motor** | Driver MongoDB asynchrone pour Python |
| **PyMongo** | Driver MongoDB synchrone (scripts) |

### IA & Agent Conversationnel

| Technologie | Rôle |
|---|---|
| **LangChain** | Orchestration des chaînes LLM et des outils IA |
| **LangGraph** | Graphe d'état pour l'agent autonome multi-étapes (AVA) |
| **RAG (Retrieval-Augmented Generation)** | Interrogation de la base de connaissances vectorielle (politique, CGU) |
| **ChromaDB (Vector Store) + Embeddings** | Indexation sémantique des 5 documents de l'entreprise (base de connaissances RAG) |
| **Speech-to-Text** | Reconnaissance vocale pour les commandes vocales utilisateur |
| **Gemini 2.5 Flash (Google)** | Modèle de langage sous-jacent (via LangChain `langchain-google-genai`) pour la compréhension et la génération — routage cloud unique, sans modèle local |

### Infrastructure & Déploiement

| Technologie | Rôle |
|---|---|
| **Docker** | Conteneurisation des services |
| **Docker Compose** | Orchestration multi-conteneurs (API + MongoDB) |

### Collections MongoDB

| Collection | Contenu |
|---|---|
| `users` | Comptes clients et administrateurs |
| `bookings` | Réservations de transport |
| `cars` | Catalogue de la flotte |
| `pricing_rules` | Règles et surcharges tarifaires |
| `promotions` | Codes promotionnels |
| `favorites` | Adresses sauvegardées par utilisateur |
| `notifications` | Notifications in-app par utilisateur |
| `destinations` | Fiches des destinations touristiques |
| `restaurants` | Recommandations de restaurants |
| `hotels` | Recommandations d'hôtels |
| `activities` | Activités et attractions touristiques |
| `suppliers` | Fournisseurs et sous-traitants de transport |
| `complaints` | Réclamations et feedback clients (soumis via AVA ou l'API) |
| `pricing_history` | Historique des changements de tarifs par véhicule (alimente l'analyse d'impact tarifaire d'AVA) |
| `password_resets` | Jetons de réinitialisation de mot de passe |
| `audit_log` | Journal d'audit des actions administrateur d'AVA |
| `chat_sessions` | Historique des conversations AVA par utilisateur |

---

*Projet de Fin d'Études — Carthage Transfer — dernière mise à jour : juillet 2026*
