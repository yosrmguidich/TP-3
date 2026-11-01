# Script de tests du TP3 (PowerShell, Windows)
# Prérequis : calcul-service (8081) et historique-service (8082) sont démarrés.
# Utilise curl.exe (et non l'alias PowerShell "curl").
# Pour sauvegarder la sortie pour le compte rendu :  .\tests.ps1 | Tee-Object resultats.txt

function Test($titre, $args_curl) {
    Write-Host ""
    Write-Host "=== $titre ===" -ForegroundColor Cyan
    & curl.exe -s -i @args_curl
    Write-Host ""
}

# ---------- Partie C / D / E : calcul-service ----------
Test "C.7  GET somme 2+3"            @("http://localhost:8081/calcul/somme?a=2&b=3")
Test "C.2  POST somme (mauvais verbe)" @("-X","POST","http://localhost:8081/calcul/somme?a=2&b=3")
Test "D.1  soustraction 10-4"        @("http://localhost:8081/calcul/soustraction?a=10&b=4")
Test "D.1  produit 6x7"              @("http://localhost:8081/calcul/produit?a=6&b=7")
Test "D.2  division 7/2"             @("http://localhost:8081/calcul/division?a=7&b=2")
Test "D.2  division 7/0"             @("http://localhost:8081/calcul/division?a=7&b=0")
Test "D.3  b absent"                 @("http://localhost:8081/calcul/somme?a=2")
Test "D.3  a = abc"                  @("http://localhost:8081/calcul/somme?a=abc&b=3")
Test "D.4  produit chemin 6/7"       @("http://localhost:8081/calcul/produit/6/7")
Test "E.2  somme/detail JSON"        @("http://localhost:8081/calcul/somme/detail?a=2&b=3")
Test "E.3  Accept json"              @("-H","Accept: application/json","http://localhost:8081/calcul/somme/detail?a=2&b=3")
Test "E.3  Accept xml (406 attendu)" @("-H","Accept: application/xml","http://localhost:8081/calcul/somme/detail?a=2&b=3")
Test "E.4  division/detail 7/2"      @("http://localhost:8081/calcul/division/detail?a=7&b=2")
Test "E.4  division/detail 7/0"      @("http://localhost:8081/calcul/division/detail?a=7&b=0")

# ---------- Partie F.6 : historique-service ----------
$h = @("-H","Content-Type: application/json")
Test "F.6 #1 POST somme 8+2"        ($h + @("-X","POST","-d",'{\"operateur\":\"somme\",\"a\":8,\"b\":2}',"http://localhost:8082/operations"))
Test "F.6 #2 POST division 7/2"     ($h + @("-X","POST","-d",'{\"operateur\":\"division\",\"a\":7,\"b\":2}',"http://localhost:8082/operations"))
Test "F.6 #3 GET /operations"       @("http://localhost:8082/operations")
Test "F.6 #4 GET /operations/2"     @("http://localhost:8082/operations/2")
Test "F.6 #5 GET /operations/99"    @("http://localhost:8082/operations/99")
Test "F.6 #6 POST division 7/0"     ($h + @("-X","POST","-d",'{\"operateur\":\"division\",\"a\":7,\"b\":0}',"http://localhost:8082/operations"))
Test "F.6 #7 POST operateur racine" ($h + @("-X","POST","-d",'{\"operateur\":\"racine\",\"a\":9,\"b\":0}',"http://localhost:8082/operations"))

Write-Host ""
Write-Host ">>> F.7 : ARRETEZ calcul-service maintenant, puis appuyez sur Entree" -ForegroundColor Yellow
Read-Host | Out-Null
Test "F.7 #8  GET /operations"      @("http://localhost:8082/operations")
Test "F.7 #9  GET /operations/1"    @("http://localhost:8082/operations/1")
Test "F.7 #10 POST produit 3x4"     ($h + @("-X","POST","-d",'{\"operateur\":\"produit\",\"a\":3,\"b\":4}',"http://localhost:8082/operations"))

Write-Host ""
Write-Host ">>> RELANCEZ calcul-service, attendez son demarrage, puis appuyez sur Entree" -ForegroundColor Yellow
Read-Host | Out-Null
Test "F.7 #10 (bis) POST produit 3x4 -> 201, id 3" ($h + @("-X","POST","-d",'{\"operateur\":\"produit\",\"a\":3,\"b\":4}',"http://localhost:8082/operations"))

# ---------- Partie F.8 : PUT ----------
Test "F.8 PUT /operations/1 produit 8x2" ($h + @("-X","PUT","-d",'{\"operateur\":\"produit\",\"a\":8,\"b\":2}',"http://localhost:8082/operations/1"))
Test "F.8 GET /operations/1"        @("http://localhost:8082/operations/1")
Test "F.8 PUT id inconnu (404)"     ($h + @("-X","PUT","-d",'{\"operateur\":\"produit\",\"a\":8,\"b\":2}',"http://localhost:8082/operations/99"))
Test "F.8 PUT division par 0 (400)" ($h + @("-X","PUT","-d",'{\"operateur\":\"division\",\"a\":8,\"b\":0}',"http://localhost:8082/operations/1"))

# ---------- Partie F.9 : DELETE ----------
Test "F.9 DELETE /operations/1 (204)" @("-X","DELETE","http://localhost:8082/operations/1")
Test "F.9 GET /operations/1 (404)"    @("http://localhost:8082/operations/1")
Test "F.9 DELETE /operations/1 (404)" @("-X","DELETE","http://localhost:8082/operations/1")
