# TP3 REST : Microservices « Calculatrice » avec Spring Boot

**Matière :** Architecture MicroServices 

**Filière :** MPSRCC1

**Réalisé par :** Mguidich Yosr

Deux microservices indépendants :
- `calcul-service` — port **8081**
- `historique-service` — port **8082**

---

## 0. Environnement et choix de version

| Élément | Valeur utilisée |
|---|---|
| JDK | Temurin 21.0.13 |
| Spring Boot | 3.3.1 (voir remarque) |
| Dépendance web | `spring-boot-starter-web` |
| Build | Maven (`mvnw` / IntelliJ) |

**Remarque :** Le TP impose Spring Boot 4.0.9 avec la dépendance `spring-boot-starter-webmvc`. Cette version n'a pas pu être résolue sur mon poste. Le sujet précise qu'avec une version 3.x, seul le nom de la dépendance change (`spring-boot-starter-web`) et que le reste est identique. Le code est donc le même. Pour passer en 4.0.9, il suffit de changer la version du parent et le nom du starter dans les deux fichiers `pom.xml`.

**Paquetages :**
- `com.exemple.calculservice1` pour `calcul-service` (nom donné par mon projet IntelliJ).
- `com.exemple.historique` pour `historique-service`.

## 1. Structure du dépôt

```text
tp3/
├── calcul-service/
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/exemple/calculservice1/
│       │   ├── CalculService1Application.java
│       │   ├── controller/CalculController.java
│       │   ├── service/Calculatrice.java
│       │   └── model/Resultat.java
│       └── resources/application.properties      (port 8081)
├── historique-service/
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/exemple/historique/
│       │   ├── HistoriqueServiceApplication.java
│       │   ├── controller/OperationController.java
│       │   ├── service/OperationService.java
│       │   ├── client/CalculClient.java
│       │   └── model/Operation.java
│       └── resources/application.properties      (port 8082, calcul.service.url)
├── tests.ps1                                      (script de tests)
└── README.md
```

## 2. Lancer les microservices

Ouvrir deux terminaux, un par microservice.

**Terminal 1 — calcul-service**

```bash
cd calcul-service
mvn clean package
java -jar target/calcul-service-0.0.1-SNAPSHOT.jar
```

**Terminal 2 — historique-service**

```bash
cd historique-service
mvn clean package
java -jar target/historique-service-0.0.1-SNAPSHOT.jar
```

Dans les consoles, les lignes suivantes doivent apparaître (captures à joindre) :

```text
Tomcat started on port 8081 (http)
Tomcat started on port 8082 (http)
```

> Si Maven n'est pas installé globalement, utiliser le wrapper `mvnw` fourni avec le projet (`mvnw.cmd` sous Windows) ou les tâches Maven d'IntelliJ.

## 3. Réponses aux questions

### Partie A — Questions de conception

**A.4.1 — Avantage et inconvénient d'une requête HTTP à la place d'un appel de méthode**

- **Avantage :** `calcul-service` est autonome. On peut le modifier, le redéployer, le dupliquer ou le remplacer sans toucher à `historique-service`.
- **Inconvénient :** l'appel passe par le réseau. Il est plus lent qu'un appel de méthode et il peut échouer si l'autre service est arrêté ou injoignable.

**A.4.2 — Si calcul-service est arrêté**

Tout ce qui est servi sur le port 8081 échoue (connexion refusée) : les quatre calculs GET.

Côté `historique-service` :
- `GET /operations`, `GET /operations/{id}` et `DELETE /operations/{id}` continuent de fonctionner, car ils n'ont pas besoin de calcul.
- `POST /operations` et `PUT /operations/{id}` échouent, car ils doivent obtenir le résultat auprès de `calcul-service`.

**A.4.3 — Pourquoi deux microservices ne peuvent pas écouter sur le même port**

Un port ne peut être ouvert (« bind ») que par un seul processus à la fois. Le second démarrage échouerait avec une erreur du type `Port ... was already in use`.

**A.4.4 — Code de statut quand calcul-service est injoignable**

`503 Service Unavailable` : le serveur ne peut pas répondre pour l'instant parce qu'un service dont il dépend est indisponible. Ce n'est ni une erreur du client (4xx), ni un bug de `historique-service`.

### Partie C

#### Tableau de correspondance (C.2)

| Spring (TP3) | JAX-RS (TP2) | Rôle dans cet exemple |
|---|---|---|
| `@RestController` | Pas d'équivalent direct | Déclare la classe comme contrôleur REST géré par Spring. La valeur retournée par chaque méthode est écrite directement dans le corps de la réponse. |
| `@RequestMapping("/calcul")` | `@Path("/calcul")` sur la classe | Préfixe commun de toutes les URI de la classe. |
| `@GetMapping("/somme")` | `@GET` + `@Path("/somme")` | La méthode répond aux requêtes GET sur `/calcul/somme`. |
| `produces = MediaType.TEXT_PLAIN_VALUE` | `@Produces(MediaType.TEXT_PLAIN)` | Type de contenu de la réponse (`Content-Type: text/plain`). |
| `@RequestParam("a") int a` | `@QueryParam("a") int a` | Lit le paramètre de requête `?a=...`. |
| `ResponseEntity.ok(...)` | `Response.ok(...).build()` | Construit une réponse de statut 200 avec un corps. |

**Origine des parties de l'URL (C.6)**

- `/somme` vient de l'annotation `@GetMapping("/somme")` de la méthode.
- `?a=2&b=3` correspond aux paramètres de requête lus par `@RequestParam("a")` et `@RequestParam("b")`.

**Question C.1**

Par rapport à `http://localhost:8080/RestWebApp/api/calcul/somme?a=2&b=3`, trois choses ont disparu ou changé :

1. **`/RestWebApp` :** c'était le nom du `.war` déployé dans Tomcat, qui sert plusieurs applications sous un même port. Ici, l'application est seule dans son serveur embarqué ; elle est à la racine `/`.
2. **`/api` :** c'était le préfixe de `@ApplicationPath("/api")` de la classe `RestApplication`. Spring Boot n'a pas besoin de cette classe, donc ce préfixe n'existe plus.
3. **Le port :** il passe de 8080 (celui de Tomcat, partagé) à 8081 (propre au microservice, défini par `server.port`).

**Question C.2 — Requête POST sur une URI déclarée en GET**

Une requête `POST /calcul/somme` renvoie `405 Method Not Allowed`, car seule la méthode GET est déclarée sur cette URI. C'est le même statut qu'au TP2 : la règle vient du protocole HTTP, pas de l'outil.

### Partie D

**D.3 — Observations (statuts attendus avec Spring)**

- `GET /calcul/somme?a=2` : **400 Bad Request**. Le paramètre obligatoire `b` est absent ; la méthode n'est pas exécutée.
- `GET /calcul/somme?a=abc&b=3` : **400 Bad Request**. `abc` ne peut pas être converti en `int`.

**Question D.1**

Spring refuse la requête avec un 400 au lieu d'exécuter la méthode avec 0. C'est l'attitude la plus conforme à REST : une requête incomplète ou mal formée est une erreur du client et doit être signalée par un statut 4xx. Utiliser silencieusement la valeur 0 donnerait un résultat faux sans prévenir.

**Question D.2**

L'objet JSON d'erreur de Spring Boot contient les champs `timestamp`, `status`, `error` et `path`. Le champ `message` n'est pas inclus par défaut.

**Question D.3 — Correspondance des paramètres**

| Spring | JAX-RS |
|---|---|
| `@RequestParam` | `@QueryParam` |
| `@PathVariable` | `@PathParam` |

Pour lire l'identifiant dans `/operations/{id}`, on utilise `@PathVariable("id")`.

### Partie E

**Question E.1**

Oui, les deux textes JSON sont équivalents : en JSON, les membres d'un objet ne sont pas ordonnés. Un client qui lit les champs par leur nom obtient donc les mêmes valeurs. Cette fois, la conversion est faite par Jackson (inclus dans Spring Boot), et non par JSON-B.

**Question E.2**

La seconde requête (`Accept: application/xml`) reçoit **406 Not Acceptable**. Même si le code ne mentionne aucun format, Spring ne dispose que de convertisseurs capables de produire du JSON pour un objet `Resultat` (aucune bibliothèque XML n'est présente). Il ne peut donc pas satisfaire le format demandé par le client.

**E.4 — Exercice**

La méthode `divisionDetail` est dans `CalculController` : `GET /calcul/division/detail?a=...&b=...` renvoie un `Resultat` en JSON, ou le statut 400 si `b` vaut 0.

### Partie F

**Question F.1**

Les lectures (GET) lisent la liste en mémoire dans `historique-service`. Elles n'ont besoin d'aucun calcul et donc d'aucun appel à `calcul-service`.

Au TP2, c'était impossible : l'historique et la calculatrice étaient dans le même `.war`. Si l'application s'arrêtait, tout s'arrêtait ; il n'y avait pas de panne partielle.

**Question F.2**

Sans le bloc `catch (ResourceAccessException e)`, l'exception remonterait hors du contrôleur et Spring répondrait `500 Internal Server Error`, ce qui laisserait croire à un bug de `historique-service`. Avec le bloc, le client reçoit un `503` clair, qui indique que le problème vient d'un service dont on dépend.

## 4. Tests

Les tableaux « attendu » ci-dessous sont déduits du code. Les captures Postman ou les sorties `curl -i` réellement obtenues sont à joindre dans la section 5. Le script `tests.ps1` lance toutes les requêtes.

### Calculs (parties C, D, E)

| Requête | Statut | Corps attendu |
|---|---:|---|
| `GET :8081/calcul/somme?a=2&b=3` | 200 | `5` |
| `GET :8081/calcul/soustraction?a=10&b=4` | 200 | `6` |
| `GET :8081/calcul/produit?a=6&b=7` | 200 | `42` |
| `GET :8081/calcul/division?a=7&b=2` | 200 | `3.5` |
| `GET :8081/calcul/division?a=7&b=0` | 400 | `Erreur : division par 0 impossible` |
| `GET :8081/calcul/produit/6/7` | 200 | `42` |
| `GET :8081/calcul/somme/detail?a=2&b=3` | 200 | `{"operation":"somme","a":2,"b":3,"resultat":5.0}` |
| Même requête avec `Accept: application/xml` | 406 | Aucun |

### F.6 — Création et lecture

| N° | Requête | Corps envoyé | Statut | Réponse attendue |
|---:|---|---|---:|---|
| 1 | `POST /operations` | `{"operateur":"somme","a":8,"b":2}` | 201 (en-tête `Location: .../operations/1`) | `{"id":1,"operateur":"somme","a":8,"b":2,"resultat":10.0}` |
| 2 | `POST /operations` | `{"operateur":"division","a":7,"b":2}` | 201 | `{"id":2,"operateur":"division","a":7,"b":2,"resultat":3.5}` |
| 3 | `GET /operations` | Aucun | 200 | Liste des opérations 1 et 2 |
| 4 | `GET /operations/2` | Aucun | 200 | Opération 2 |
| 5 | `GET /operations/99` | Aucun | 404 | Aucun corps |
| 6 | `POST /operations` | `{"operateur":"division","a":7,"b":0}` | 400 | `{"erreur":"Division par 0 impossible"}` |
| 7 | `POST /operations` | `{"operateur":"racine","a":9,"b":0}` | 400 | `{"erreur":"Opérateur inconnu : racine"}` |

### F.7 — calcul-service arrêté

| N° | Requête | Corps envoyé | Statut | Réponse attendue |
|---:|---|---|---:|---|
| 8 | `GET /operations` | Aucun | 200 | La liste en mémoire |
| 9 | `GET /operations/1` | Aucun | 200 | Opération 1 |
| 10 | `POST /operations` | `{"operateur":"produit","a":3,"b":4}` | 503 | `{"erreur":"calcul-service est indisponible"}` |

Après redémarrage de `calcul-service`, la requête 10 répond `201` avec l'identifiant 3. Les échecs des requêtes 6, 7 et 10 n'ont pas consommé d'identifiant : le compteur n'est incrémenté qu'après un calcul réussi.

### F.8 — PUT

| Situation | Statut | Corps de la réponse |
|---|---:|---|
| Aucune opération ne porte cet identifiant | 404 | `{"erreur":"Opération 99 introuvable"}` |
| Calcul impossible (opérateur inconnu, division par 0) | 400 | `{"erreur":"..."}` |
| `calcul-service` injoignable | 503 | `{"erreur":"calcul-service est indisponible"}` |
| Modification réussie | 200 | Opération modifiée (ex. résultat = 16.0 pour produit 8 × 2) |

### F.9 — DELETE

| Situation | Statut | Corps |
|---|---:|---|
| Identifiant inexistant | 404 | Aucun |
| Suppression réussie | 204 | Aucun |

**Enchaînement attendu :**
1. `DELETE /operations/1` → 204
2. `GET /operations/1` → 404
3. `DELETE /operations/1` → 404

## 5. Captures à joindre

Ajouter dans le dossier `captures/` :

- Les deux consoles avec `Tomcat started on port 8081` et `Tomcat started on port 8082`.
- Les sorties `curl -i` ou captures Postman des tests F.6, F.7, F.8 et F.9.

## 6. Questions de synthèse

### 1. Étape du TP où chaque différence du tableau A.3 est observée

| Aspect | Étape |
|---|---|
| Technologie (Spring MVC au lieu de JAX-RS) | B.3, C.2 |
| Découpage en deux applications | A.2, partie F (F.1) |
| Résultat de la construction (`.jar`) | B.3, C.5 |
| Serveur (Tomcat embarqué) | B.3, C.5 |
| Port (un par microservice) | C.4, F.1 |
| Adresse | C.6, question C.1 |
| Activation (`@SpringBootApplication` et `main`) | B.4 |
| Ressource REST (`@RestController`, `@RequestMapping`) | C.2 |
| Verbes HTTP (`@GetMapping`, `@PostMapping`...) | C.2, F.5, F.8, F.9 |
| Paramètres (`@RequestParam`, `@PathVariable`, `@RequestBody`) | C.2, D.4, F.5 |
| Réponse HTTP (`ResponseEntity`) | C.2, D.2, F.5 |
| Conversion JSON (Jackson) | E.2 |
| Création des objets (`@Service`, injection) | C.1, F.4 |
| Communication (requête HTTP) | F.3, F.7 |

### 2. Correspondance complète des annotations JAX-RS et Spring

| JAX-RS (TP2) | Spring (TP3) |
|---|---|
| `@ApplicationPath` + classe `RestApplication` | `@SpringBootApplication` + méthode `main` |
| `@Path("/x")` sur la classe | `@RestController` + `@RequestMapping("/x")` |
| `@GET` + `@Path("/y")` | `@GetMapping("/y")` |
| `@POST` | `@PostMapping` |
| `@PUT` + `@Path("/{id}")` | `@PutMapping("/{id}")` |
| `@DELETE` + `@Path("/{id}")` | `@DeleteMapping("/{id}")` |
| `@QueryParam` | `@RequestParam` |
| `@PathParam` | `@PathVariable` |
| Paramètre objet + `@Consumes(APPLICATION_JSON)` | `@RequestBody` |
| `@Produces(...)` | `produces = ...` |
| `Response` | `ResponseEntity` |
| `UriInfo.getAbsolutePathBuilder()` | `ServletUriComponentsBuilder.fromCurrentRequest()` |
| `new Calculatrice()` | `@Service` + injection par constructeur |

### 3. Construire et lancer les deux microservices sans IntelliJ

Dans deux terminaux, à la racine de chaque projet :

```bash
mvn clean package
```

Puis lancer :

```bash
java -jar target/calcul-service-0.0.1-SNAPSHOT.jar
```

Dans le second terminal :

```bash
java -jar target/historique-service-0.0.1-SNAPSHOT.jar
```

Chaque `.jar` contient son serveur Tomcat. Il n'y a rien à déployer, mais il y a deux commandes de lancement au lieu d'un seul déploiement.

### 4. Microservice et service web

Un microservice est bien un service web : il expose son API par HTTP (URI, verbes, JSON), comme `calcul-service` et `historique-service`.

L'inverse est faux : le `RestWebApp.war` du TP2 était un service web, mais pas un microservice. Il regroupait le calcul et l'historique dans une seule application déployée dans un serveur externe.

Un microservice se définit en plus par son autonomie (serveur embarqué, port propre, déploiement indépendant) et par sa responsabilité unique.

### 5. Adresse de calcul-service écrite dans application.properties

L'adresse désigne une seule instance. Avec trois exemplaires, `historique-service` enverrait toutes ses requêtes au même, qui resterait surchargé, tandis que les autres ne serviraient à rien. Si cette instance tombe, `historique-service` n'en connaît pas d'autre.

Il faut un mécanisme qui connaisse les instances disponibles et répartisse la charge (découverte de services et équilibrage, vus au TP4).

### 6. Principe stateless et liste des opérations

Le principe stateless interdit de mémoriser l'état de la conversation avec le client (par exemple une session) : chaque requête doit contenir tout ce qu'il faut pour être traitée.

La liste des opérations est une donnée de l'application (l'état des ressources), pas un état de session. Le serveur répond de la même façon quel que soit le client ou l'historique de ses requêtes précédentes.

En revanche, ce stockage en mémoire est perdu à l'arrêt et ne serait pas partagé entre plusieurs instances.

### 7. Répéter un POST et un PUT

- `POST /operations` envoyé deux fois crée deux opérations (identifiants 1 et 2) : un POST n'est pas idempotent.
- `PUT /operations/1` envoyé deux fois donne le même état final (l'opération 1 remplacée par les mêmes valeurs) : un PUT est idempotent.

Les réponses sont les mêmes qu'au TP2, car cette différence vient de la sémantique HTTP des verbes et ne dépend pas de l'outil (JAX-RS ou Spring).
