Vasilescu Andrei
Grupa 334 CD

Pentru inceput, am alocat memorie pe GPU variabilelor de care voi avea nevoie in executia kernelului. Am alocat memorie pentru nonce-ul corect gasit si
pentru hash-ul rezultat in urma nonce-ului corect ales. De asemenea, am alocat memorie pentru "block_content" initial (hash-ul block-ului anterior si root
hash) unde am copiat block content-ul obtinut pe host pentru a il putea da mai departe catre kernel ca parametru. Am folosit 64 de block-uri cu cat 512 thread-uri
deoarece am incercat cu mai multe configuratii (128 block-uri cu 256 de thread-uri, 128 block-uri cu 512 thread-uri), iar pentru aceasta configuratie am obtinut 
cei mai buni timpi. Am calculat apoi, pe baza numarului de blocuri si thread-uri utilizate, numarul de nonce-uri de verificat care ii revine fiecarui thread in parte
pentru a avea o munca egala, de asemenea, copiind aceasta valoare in memoria de pe GPU. Am folosit de asemenea si un flag care se va face 1 atunci cand se va gasi
un nonce valid, pentru a "notifica" restul threadurilor ca este momentul sa se opreasca cautarea.

In kernel, se va da ca parametru block_content-ul din main, un pointer catre o zona de memorie alocata unde se va pune hash-ul gasit cu nonce-ul potrivit si una pentru 
nonce-ul valid gasit, flag-ul pentru notificare, numarul de nonce-uri care ii revine fiecarui thread pentru verificare si hash-ul de dificultate copiat in memoria de pe 
GPU. Fiecare thread isi va calcula initial thread id-ul in functie de blockId, dimensiune block-ului si threadId, iar in functie de acest threadId se va obtine nonce-ul
de la care thread-ul trebuie sa porneasca cautarea, pentru ca fiecare thread sa aiba un alt range de nonce-uri de verificat in paralel. Apoi, am alocat local fiecarui
thread un block_hash unde se va pune la fiecare alt nonce, hash-ul rezultat pentru a putea verifica daca este valid sau nu si un block_content unde se va copia initial 
block_content-ul dat ca parametru in kernel si apoi, la fiecare nonce, se va concatena acesta pentru a putea calcula un nou hash. Dupa toate acestea, va incepe bucla
de cautare a nonce-ului, fiecare thread verificand doar nonce-urile din portiunea care ii revine. In bucla, se va verifica initial daca flag-ul de nonce valid gasit este
1, iar daca este thread-ul isi va termina executia deoarece inseamna, ca un alt thread deja a gasit un nonce valid. Daca inca nu s-a gasit un nonce valid, thread-ul
va calcula in vectorul local noul hash, cu un nou nonce si va verifica apoi daca hash-ul obtinut este unul valid adica daca respecta dificultatea ceruta si daca flag-ul
nu a fost setat. Daca cele doua conditii sunt adevarate, se va modifica atomic valoarea flag-ului la 1, cu functia "atomicExch" si apoi se va pune in zona de memorie unde
se stocheaza rezultatul, hash-ul obtinut, iar in zona de memorie unde retinem nonce-ul valid, nonce-ul actual la care am ramas in bucla, apoi thread-ul terminandu-si executia.

In urma terminarii executiei tuturor thread-urilor, voi copia inapoi de pe device pe host nonce-ul corect gasit si hash-ul obtinut cu acesta pentru a putea fi printata in csv
si voi dezaloca memoria alocata anterior pe device, dar si pe host.