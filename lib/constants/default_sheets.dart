/// Fiches pédagogiques créées au premier lancement de l'application d'origine.
/// Le contenu de « Course de vitesse 60m » a été relevé dans la vidéo. Les trois autres
/// (Handball, Gymnastique au sol, Demi-fond) sont créées avec un texte vide, modifiable
/// librement par l'enseignant (choix du propriétaire du projet).
class DefaultSheet {
  final String title, discipline, text;
  const DefaultSheet(this.title, this.discipline, this.text);
}

const List<DefaultSheet> kDefaultSheets = [
  DefaultSheet(
    'Course de vitesse 60m (Départ & Accélération)',
    'Course de vitesse',
    '''OBJECTIFS PÉDAGOGIQUES :
- Maîtriser le départ accroupi (starting-blocks ou debout 3 appuis).
- Maintenir une accélération progressive sur les 20 premiers mètres.
- Conserver l'alignement corporel et une fréquence gestuelle maximale.

ÉCHAUFFEMENT (15 min) :
1. Trottinement progressif 5 min + montées de genoux, talons-fesses.
2. Gammes dynamiques : griffés du sol, foulées bondissantes.
3. 3 départs progressifs sur 15m, 20m, 30m.

SITUATIONS D'APPRENTISSAGE / ATELIERS :
- Atelier 1 : Départs en réaction au signal sonore (claquoir / sifflet).
- Atelier 2 : Course en sur-vitesse avec repères visuels (lattes au sol espacées de 1.50m à 1.80m).
- Atelier 3 : Duel en binômes de même niveau sur 40m chronométré.

CRITÈRES DE RÉUSSITE & ÉVALUATION :
- Temps de réaction vif (< 0.5s au signal).
- Poussée complète de la jambe arrière sans redressement précoce.
- Maintien de la trajectoire rectiligne.

CONSIGNES DE SÉCURITÉ :
- Distance de décélération de 25m obligatoire après la ligne d'arrivée.
- Sol sec et couloirs matérialisés. Chaussures de sport lacées.''',
  ),
  DefaultSheet('Handball (Circulation de balle & Attaque placée)', 'Handball', ''),
  DefaultSheet('Gymnastique au sol (Éléments de liaison & Enchaînement)', 'Gymnastique', ''),
  DefaultSheet("Demi-fond (Régularité d'allure & VMA)", 'Course de demi-fond', ''),
];
