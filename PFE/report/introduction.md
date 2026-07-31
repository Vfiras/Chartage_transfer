# Introduction

## Contexte et problématique

Le secteur du transport privé en Tunisie repose encore largement sur des pratiques manuelles. La réservation d'un transfert privé — qu'il s'agisse d'un trajet aéroport, d'un transfert hôtelier ou d'un déplacement interurbain — implique aujourd'hui des échanges téléphoniques répétés, des confirmations par messagerie instantanée, et une coordination manuelle entre le client, le prestataire et le chauffeur. Cette fragmentation engendre des problèmes récurrents : disponibilité incertaine des véhicules, tarification opaque, absence de traçabilité, et expérience client hétérogène selon l'interlocuteur.

Pour les opérateurs de transport privé à la clientèle internationale — notamment les sociétés desservant les aéroports de Tunis-Carthage, Monastir et Djerba — cette réalité représente un frein à la croissance. L'absence d'une plateforme numérique unifiée contraint les agences à allouer des ressources humaines significatives à des tâches de coordination répétitives, au détriment de la qualité de service et de la scalabilité de l'activité.

## Solution proposée : Carthage Transfer

Ce projet de fin d'études propose la conception et le développement de **Carthage Transfer**, une plateforme numérique de réservation de transport privé haut de gamme, destinée à moderniser l'expérience client et à rationaliser les opérations internes de gestion de flotte.

La plateforme se compose de deux axes principaux. D'une part, une **application mobile multiplateforme** (iOS et Android) permettant aux clients de rechercher des transferts, de comparer les véhicules disponibles, de consulter des tarifs transparents tenant compte de majorations dynamiques, et de finaliser leur réservation en quelques étapes. D'autre part, un **tableau de bord d'administration** offrant aux opérateurs une visibilité en temps réel sur les réservations, la flotte, les promotions, et les indicateurs d'activité.

L'élément distinctif de cette plateforme est **AVA** (*Automated Virtual Assistant*), un agent conversationnel intégré directement dans l'interface client. AVA répond aux questions relatives aux transferts, guide l'utilisateur dans le processus de réservation, gère les demandes de modification d'itinéraires, et fournit des informations sur le programme de fidélité. L'ambition n'est pas de reproduire un chatbot générique, mais de construire un agent contextualisé à l'activité de Carthage Transfer, fondé sur des données réelles et soumis à des mécanismes de contrôle explicites.

## Périmètre technique

La solution repose sur un socle technologique moderne, choisi pour sa cohérence avec les exigences d'une application mobile grand public et d'un système d'intelligence artificielle productif.

L'**application cliente** est développée en **Flutter** (framework Dart de Google), ce qui garantit un rendu natif sur Android et iOS à partir d'une base de code unique. Le **backend** est implémenté en **Python** avec le framework **FastAPI**, une solution asynchrone performante, et expose une API REST consommée par l'application et le tableau de bord d'administration.

Les données sont persistées dans **MongoDB**, une base de données documentaire adaptée à la flexibilité des schémas de réservation et à l'évolutivité des données utilisateur. La communication en temps réel entre le backend et le client AVA est assurée via des flux **Server-Sent Events** (SSE), permettant le streaming progressif des réponses de l'agent.

L'architecture d'AVA repose sur **LangGraph**, une bibliothèque de construction de graphes d'agents conversationnels. Le superviseur orchestre six agents spécialisés : réservation, support, fidélité, retours clients, opérations d'administration et analyse. La sélection du modèle de langage suit une stratégie à trois niveaux : un modèle local (**Ollama / llama3.1:8b**) pour les tâches de classification et de récupération documentaire, et **Gemini 2.5 Flash** de Google pour les tâches de synthèse et les requêtes d'administration, avec dégradation gracieuse en cas d'indisponibilité du service cloud.

## Structure du rapport

Ce rapport est organisé en sept chapitres. Le premier présente l'analyse du besoin et les spécifications fonctionnelles de la plateforme. Le deuxième décrit l'architecture technique du système et les choix de conception. Le troisième expose l'implémentation de l'application mobile Flutter et l'expérience utilisateur client. Le quatrième détaille la conception et le développement du backend FastAPI, des modèles de données et des services métier. Le cinquième chapitre est consacré à l'architecture multi-agents d'AVA : la conception du superviseur LangGraph, les six agents, les mécanismes de routage et les gardes de sécurité. Le sixième chapitre présente la démarche qualité : les harnesses d'évaluation, les métriques de performance et les résultats obtenus. Le septième et dernier chapitre dresse un bilan critique du projet, identifie les limites actuelles et propose des perspectives d'évolution.
