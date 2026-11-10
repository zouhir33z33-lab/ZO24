/// Listes proposées dans l'écran de déclaration d'accident (libellés arabes relevés
/// dans la vidéo ; équivalents FR/EN = APPROXIMATION).
class Choice {
  final String code; // valeur stockée
  final String ar, fr, en;
  const Choice(this.code, this.ar, this.fr, this.en);
  String label(String lang) => lang == 'ar' ? ar : (lang == 'en' ? en : fr);
}

const List<Choice> kInjuryTypes = [
  Choice('ENTORSE', 'التواء المفصل', 'Entorse', 'Sprain'),
  Choice('CONTUSION', 'كدمة / رض', 'Contusion', 'Bruise'),
  Choice('PLAIE', 'جرح / قطع', 'Plaie / coupure', 'Wound / cut'),
  Choice('MALAISE', 'وعكة صحية / دوار', 'Malaise / vertige', 'Dizziness'),
  Choice('TRAUMA_TETE', 'صدمة في الرأس', 'Traumatisme crânien', 'Head trauma'),
  Choice('FRACTURE', 'اشتباه بكسر', 'Suspicion de fracture', 'Suspected fracture'),
  Choice('LUXATION', 'خلع في المفصل', 'Luxation', 'Dislocation'),
  Choice('EPISTAXIS', 'رعاف (نزيف أنفي)', 'Saignement de nez', 'Nosebleed'),
  Choice('BRULURE', 'حرق / احتكاك جلدي', 'Brûlure / frottement', 'Burn / friction'),
  Choice('AUTRE', 'إصابة أخرى', 'Autre blessure', 'Other injury'),
];

const List<Choice> kLocations = [
  Choice('Terrain Extérieur 1', 'الميدان الخارجي 1', 'Terrain Extérieur 1', 'Outdoor field 1'),
  Choice('Terrain Extérieur 2', 'الميدان الخارجي 2', 'Terrain Extérieur 2', 'Outdoor field 2'),
  Choice('Salle de sport', 'قاعة الرياضة / القاعة', 'Salle de sport', 'Sports hall'),
  Choice('Aire de lancer / saut', 'ميدان الرمي / الوثب', 'Aire de lancer / saut', 'Throwing / jumping area'),
  Choice('Piste d\'athlétisme', 'مضمار ألعاب القوى', 'Piste d\'athlétisme', 'Athletics track'),
  Choice('Vestiaires', 'غرف تبديل الملابس', 'Vestiaires', 'Changing rooms'),
];

/// Valeurs stockées en français (la colonne evacuation_type vaut 'Infirmerie scolaire' par défaut).
const List<Choice> kEvacuations = [
  Choice('Infirmerie scolaire', 'تلقي الإسعافات الأولية في المؤسسة', 'Soins à l\'infirmerie de l\'établissement', 'First aid at school'),
  Choice('Famille / proches', 'نقل من أحد الأولياء أو الأقارب', 'Pris en charge par la famille / un proche', 'Taken by family / relative'),
  Choice('Ambulance', 'نقل بسيارة الإسعاف', 'Transfert en ambulance', 'Ambulance transfer'),
  Choice('Hôpital accompagné', 'نقل إلى المستشفى مع مرافق من المؤسسة', 'Transfert à l\'hôpital avec accompagnateur', 'Hospital transfer with escort'),
];

const List<Choice> kFirstAid = [
  Choice('Glace / Vessie réfrigérante', 'ثلج / كمادة باردة', 'Glace / Vessie réfrigérante', 'Ice pack'),
  Choice('Repos et immobilisation', 'راحة ورفع العضو المصاب', 'Repos et surélévation', 'Rest and elevation'),
  Choice('Pansement', 'تضميد الجرح', 'Pansement', 'Dressing'),
  Choice('Désinfection', 'تعقيم', 'Désinfection', 'Disinfection'),
];

Choice? choiceOf(List<Choice> list, String? code) {
  for (final c in list) {
    if (c.code == code) return c;
  }
  return null;
}

/// Texte par défaut quand les circonstances ne sont pas renseignées (relevé dans la vidéo et le PDF d'origine).
const String kDefaultCircumstances =
    "Blessure survenue pendant la pratique d'activités physiques en séance d'EPS.";
