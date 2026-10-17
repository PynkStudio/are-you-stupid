import Foundation

public enum PresenterIntensity: String, Codable, CaseIterable, Sendable {
    case neutral
    case savage
}

public enum PresenterGameMode: String, Sendable {
    case battle
    case lastStupidStanding
}

public enum PresenterCueKind: String, Codable, Sendable {
    case lobby
    case roundResult
    case elimination
    case title
    case gameEnd
}

public enum PresenterExpiry: Equatable, Sendable {
    case whileLobby
    case throughResults(roundId: String)
    case beforeNextRound(roundId: String)
    case whileFactIsTrue(key: String)
    case whileGameEnd
}

public struct PresenterCue: Equatable, Sendable {
    public let id: String
    public let kind: PresenterCueKind
    public let text: String
    public let targetPlayerId: String?
    public let expiry: PresenterExpiry
    public let cacheable: Bool
    /// Pre-recorded audio for this exact line, when the line book has one.
    public let clip: PresenterLineBook.Clip?

    public init(id: String, kind: PresenterCueKind, text: String, targetPlayerId: String? = nil, expiry: PresenterExpiry, cacheable: Bool, clip: PresenterLineBook.Clip? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.targetPlayerId = targetPlayerId
        self.expiry = expiry
        self.cacheable = cacheable
        self.clip = clip
    }
}

public struct PresenterPlayer: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let spokenName: String?

    public init(id: String, displayName: String, spokenName: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.spokenName = spokenName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct PresenterRoundFact: Equatable, Sendable {
    public let roundId: String
    public let correctPlayerIds: [String]
    public let wrongPlayerIds: [String]
    public let challengeId: String?
    public let mode: PresenterGameMode
    public let remainingLivesByPlayer: [String: Int]

    public init(roundId: String, correctPlayerIds: [String], wrongPlayerIds: [String], challengeId: String? = nil, mode: PresenterGameMode = .battle, remainingLivesByPlayer: [String: Int] = [:]) {
        self.roundId = roundId
        self.correctPlayerIds = correctPlayerIds
        self.wrongPlayerIds = wrongPlayerIds
        self.challengeId = challengeId
        self.mode = mode
        self.remainingLivesByPlayer = remainingLivesByPlayer
    }

    public var mechanic: PresenterMechanic? { challengeId.flatMap(PresenterMechanic.init(challengeId:)) }
}

/// Editorial categories deliberately coarser than challenge ids. They let the
/// line book roast the verified action without coupling copy to 39 templates.
public enum PresenterMechanic: String, CaseIterable, Sendable {
    case button, math, counting, reading, waiting, timing, memory, direction, perception

    public init?(challengeId: String) {
        let byMechanic: [PresenterMechanic: Set<String>] = [
            .button: ["tap_color", "tap_number", "tap_color_moving", "tap_nothing_button", "fake_buttons"],
            .math: ["math"],
            .counting: ["tap_twice", "tap_exactly_n", "count_shapes", "spam_taps", "spell_count"],
            .reading: ["dont_tap_color", "dont_tap_color_shifting", "tap_actual_color", "tap_the_word", "tap_word_button", "odd_word_out", "tap_unwritten_color", "ignore_next", "rule_flip"],
            .waiting: ["dont_tap", "do_nothing", "no_instruction", "dont_follow", "wait_for_green", "too_fast"],
            .timing: ["hold_button", "precise_timing"],
            .memory: ["remember_color", "remember_position", "remember_number", "last_color"],
            .direction: ["opposite", "left_right_swap", "tap_in_order", "tap_reverse_order"],
            .perception: ["spot_different", "size_compare", "didnt_change"],
        ]
        guard let match = byMechanic.first(where: { $0.value.contains(challengeId) })?.key else { return nil }
        self = match
    }
}

/// In-code text baseline for the line book (`PresenterLineBook.builtIn`):
/// what the host can say with no bundled pack and no network. Keep it in
/// sync with the backend's `content/ays-presenter/pack.it.json`.
public enum OfflinePresenterPack {
    public static let supportedLocales = ["en", "it", "fr", "es", "pt", "de"]

    public static let lines: [String: [String: [String]]] = [
        "en": baseline("NOBODY. PROMISING.", "NOBODY READ IT. PERFECT.", "SUSPICIOUSLY COMPETENT.", "MIXED RESULTS. VERY MIXED.", "WE HAVE A WINNER. TECHNICALLY."),
        "it": baseline("NESSUNO. PROMETTENTE.", "NESSUNO HA LETTO. PERFETTO.", "SOSPETTOSAMENTE COMPETENTI.", "RISULTATI MISTI. MOLTO MISTI.", "ABBIAMO UN VINCITORE. TECNICAMENTE."),
        "fr": baseline("PERSONNE. PROMETTEUR.", "PERSONNE N'A LU. PARFAIT.", "ÉTRANGEMENT COMPÉTENTS.", "RÉSULTATS MITIGÉS. TRÈS MITIGÉS.", "NOUS AVONS UN GAGNANT. TECHNIQUEMENT."),
        "es": baseline("NADIE. PROMETEDOR.", "NADIE LEYÓ. PERFECTO.", "SOSPECHOSAMENTE COMPETENTES.", "RESULTADOS MIXTOS. MUY MIXTOS.", "TENEMOS GANADOR. TÉCNICAMENTE."),
        "pt": baseline("NINGUÉM. PROMISSOR.", "NINGUÉM LEU. PERFEITO.", "SUSPEITAMENTE COMPETENTES.", "RESULTADOS MISTOS. MUITO MISTOS.", "TEMOS UM VENCEDOR. TECNICAMENTE."),
        "de": baseline("NIEMAND. VIELVERSPRECHEND.", "NIEMAND HAT GELESEN. PERFEKT.", "VERDÄCHTIG KOMPETENT.", "GEMISCHTE ERGEBNISSE. SEHR GEMISCHT.", "WIR HABEN EINEN SIEGER. TECHNISCH GESEHEN."),
    ]

    public static let templates: [String: [String: [PresenterLineBook.Line]]] = Dictionary(
        uniqueKeysWithValues: supportedLocales.map { locale in
            let copy: [String]
            switch locale {
            case "it": copy = ["{name}, DA ORA SEI {title}.", "DA ORA SEI {title}.", "{name} HA VINTO. TECNICAMENTE.", "È TORNATO {name}, {title}.", "È TORNATO {title}."]
            case "fr": copy = ["{name}, TU ES DÉSORMAIS {title}.", "TU ES DÉSORMAIS {title}.", "{name} A GAGNÉ. TECHNIQUEMENT.", "{name} EST DE RETOUR, {title}.", "{title} EST DE RETOUR."]
            case "es": copy = ["{name}, AHORA ERES {title}.", "AHORA ERES {title}.", "{name} HA GANADO. TÉCNICAMENTE.", "HA VUELTO {name}, {title}.", "HA VUELTO {title}."]
            case "pt": copy = ["{name}, AGORA ÉS {title}.", "AGORA ÉS {title}.", "{name} VENCEU. TECNICAMENTE.", "{name} VOLTOU, {title}.", "{title} VOLTOU."]
            case "de": copy = ["{name}, AB JETZT BIST DU {title}.", "AB JETZT BIST DU {title}.", "{name} HAT GEWONNEN. TECHNISCH GESEHEN.", "{name} IST ZURÜCK, {title}.", "{title} IST ZURÜCK."]
            default: copy = ["{name}, YOU ARE NOW {title}.", "YOU ARE NOW {title}.", "{name} WON. TECHNICALLY.", "{name} IS BACK, {title}.", "{title} IS BACK."]
            }
            let keys = ["title.named", "title.anonymous", "gameEnd.named", "lobby.returning.named", "lobby.returning.anonymous"]
            var result: [String: [PresenterLineBook.Line]] = Dictionary(
                uniqueKeysWithValues: zip(keys, copy).map { key, text in
                    (key, [PresenterLineBook.Line(id: "\(key).0", text: text)])
                }
            )
            for (key, lines) in resultTemplates(locale: locale) { result[key] = lines }
            for (key, lines) in combinedTitleTemplates(locale: locale) { result[key] = lines }
            return (locale, result)
        }
    )

    public static let titles: [String: [String: String]] = [
        "en": ["king": "THE KING", "kingUndisputed": "THE UNDISPUTED KING", "doesNotRead": "THE ONE WHO DOESN'T READ"],
        "it": ["king": "IL KING", "kingUndisputed": "IL KING INDISCUSSO", "doesNotRead": "QUELLO CHE NON LEGGE"],
        "fr": ["king": "LE ROI", "kingUndisputed": "LE ROI INCONTESTÉ", "doesNotRead": "CELUI QUI NE LIT PAS"],
        "es": ["king": "EL REY", "kingUndisputed": "EL REY INDISCUTIBLE", "doesNotRead": "EL QUE NO LEE"],
        "pt": ["king": "O REI", "kingUndisputed": "O REI INCONTESTÁVEL", "doesNotRead": "QUEM NÃO LÊ"],
        "de": ["king": "DER KÖNIG", "kingUndisputed": "DER UNANGEFOCHTENE KÖNIG", "doesNotRead": "DER, DER NICHT LIEST"],
    ]

    private static func baseline(_ lobby: String, _ wrong: String, _ correct: String, _ mixed: String, _ end: String) -> [String: [String]] {
        ["lobby.empty": [lobby], "result.everyoneWrong": [wrong], "result.everyoneCorrect": [correct], "result.mixed": [mixed], "gameEnd": [end]]
    }

    private static func resultTemplates(locale: String) -> [String: [PresenterLineBook.Line]] {
        let localized: [String: [String: String]] = [
            "it": [
                "result.mixed.oneWrong.named": "DAI, TRANQUILLO, {name}. DOPO TE LA SPIEGO, PROMESSO.",
                "result.player.stillZero": "{name}, VINCE CHI FA PIÙ PUNTI. O ALMENO CHI FA DEI PUNTI.",
                "result.player.firstPointLate": "AH, MA QUINDI LO HAI CAPITO CHE È UNA GARA, {name}?",
                "result.player.wrongStreak3": "{name}, VUOI CHIEDERE L'AIUTO DA CASA O CE LA FAI DA SOLO?",
                "result.player.lss.lastLife": "{name}, TE NE RESTA UNA. PROVA A NON BUTTARE VIA ANCHE QUESTA.",
                "result.player.lss.losingLives": "{name}, LE VITE NON SONO PUNTI. QUELLE FINISCONO.",
                "result.mixed.oneWrong.mechanic.button": "ERA UN BOTTONE, {name}. UNO.",
                "result.mixed.oneWrong.mechanic.math": "{name}, ERANO NUMERI PICCOLI APPOSTA.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, FINCHÉ BASTAVANO LE DITA SEMBRAVI COMPETITIVO.",
                "result.mixed.oneWrong.mechanic.reading": "C'ERA SCRITTO DAVANTI A TE, {name}. DAVANTI. A. TE.",
                "result.mixed.oneWrong.mechanic.waiting": "DOVEVI NON FARE NIENTE, {name}. FINALMENTE ERI QUALIFICATO.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, ERA UNA QUESTIONE DI TEMPO. E LO HAI PERSO.",
                "result.mixed.oneWrong.mechanic.memory": "ERA UNA COSA SOLA, {name}. NON LA DIVINA COMMEDIA.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, QUELLA ERA L'ALTRA SINISTRA.",
                "result.mixed.oneWrong.mechanic.perception": "{name}, ERA DAVANTI AI TUOI OCCHI. PURTROPPO ANCHE TU.",
            ],
            "en": [
                "result.mixed.oneWrong.named": "IT'S OK, {name}. I'LL EXPLAIN IT TO YOU LATER. PROMISE.",
                "result.player.stillZero": "{name}, YOU WIN BY SCORING MORE POINTS. OR AT LEAST SOME POINTS.",
                "result.player.firstPointLate": "OH, SO YOU DID REALIZE THIS WAS A COMPETITION, {name}?",
                "result.player.wrongStreak3": "{name}, WOULD YOU LIKE TO PHONE A FRIEND OR CAN YOU FAIL ALONE?",
                "result.player.lss.lastLife": "{name}, ONE LIFE LEFT. TRY NOT TO WASTE THIS ONE TOO.",
                "result.player.lss.losingLives": "{name}, LIVES AREN'T POINTS. THEY ACTUALLY RUN OUT.",
                "result.mixed.oneWrong.mechanic.button": "IT WAS ONE BUTTON, {name}. ONE.",
                "result.mixed.oneWrong.mechanic.math": "{name}, WE USED SMALL NUMBERS FOR A REASON.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, YOU LOOKED COMPETITIVE WHILE FINGERS WERE ENOUGH.",
                "result.mixed.oneWrong.mechanic.reading": "IT WAS WRITTEN IN FRONT OF YOU, {name}. IN FRONT OF YOU.",
                "result.mixed.oneWrong.mechanic.waiting": "YOU HAD TO DO NOTHING, {name}. FINALLY, YOUR SPECIALTY.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, IT WAS A MATTER OF TIME. AND YOU WASTED IT.",
                "result.mixed.oneWrong.mechanic.memory": "IT WAS ONE THING, {name}. NOT AN ENTIRE NOVEL.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, THAT WAS YOUR OTHER LEFT.",
                "result.mixed.oneWrong.mechanic.perception": "IT WAS RIGHT BEFORE YOUR EYES, {name}. SO WERE YOU.",
            ],
            "fr": [
                "result.mixed.oneWrong.named": "T'INQUIÈTE, {name}. JE T'EXPLIQUERAI APRÈS. PROMIS.",
                "result.player.stillZero": "{name}, IL FAUT MARQUER PLUS DE POINTS. OU AU MOINS UN POINT.",
                "result.player.firstPointLate": "AH, TU AVAIS COMPRIS QUE C'ÉTAIT UNE COMPÉTITION, {name} ?",
                "result.player.wrongStreak3": "{name}, TU VEUX APPELER UN AMI OU TU TE DÉBROUILLES SEUL ?",
                "result.player.lss.lastLife": "{name}, IL T'EN RESTE UNE. ESSAIE DE NE PAS GÂCHER CELLE-LÀ AUSSI.",
                "result.player.lss.losingLives": "{name}, LES VIES NE SONT PAS DES POINTS. ELLES S'ÉPUISENT.",
                "result.mixed.oneWrong.mechanic.button": "C'ÉTAIT UN BOUTON, {name}. UN SEUL.",
                "result.mixed.oneWrong.mechanic.math": "{name}, ON AVAIT CHOISI DE PETITS NOMBRES EXPRÈS.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, TANT QUE TES DOIGTS SUFFISAIENT, TU SEMBLAIS COMPÉTITIF.",
                "result.mixed.oneWrong.mechanic.reading": "C'ÉTAIT ÉCRIT DEVANT TOI, {name}. DEVANT. TOI.",
                "result.mixed.oneWrong.mechanic.waiting": "IL FALLAIT NE RIEN FAIRE, {name}. ENFIN TA SPÉCIALITÉ.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, C'ÉTAIT UNE QUESTION DE TEMPS. TU L'AS GASPILLÉ.",
                "result.mixed.oneWrong.mechanic.memory": "C'ÉTAIT UNE SEULE CHOSE, {name}. PAS UN ROMAN ENTIER.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, C'ÉTAIT TON AUTRE GAUCHE.",
                "result.mixed.oneWrong.mechanic.perception": "C'ÉTAIT SOUS TES YEUX, {name}. TOI AUSSI, MALHEUREUSEMENT.",
            ],
            "es": [
                "result.mixed.oneWrong.named": "TRANQUILO, {name}. LUEGO TE LO EXPLICO. PROMETIDO.",
                "result.player.stillZero": "{name}, GANA QUIEN HACE MÁS PUNTOS. O AL MENOS ALGÚN PUNTO.",
                "result.player.firstPointLate": "AH, ¿ENTONCES ENTENDISTE QUE ESTO ERA UNA COMPETICIÓN, {name}?",
                "result.player.wrongStreak3": "{name}, ¿QUIERES LLAMAR A UN AMIGO O PUEDES FALLAR TÚ SOLO?",
                "result.player.lss.lastLife": "{name}, TE QUEDA UNA VIDA. INTENTA NO TIRAR ESTA TAMBIÉN.",
                "result.player.lss.losingLives": "{name}, LAS VIDAS NO SON PUNTOS. SE ACABAN DE VERDAD.",
                "result.mixed.oneWrong.mechanic.button": "ERA UN BOTÓN, {name}. UNO.",
                "result.mixed.oneWrong.mechanic.math": "{name}, PUSIMOS NÚMEROS PEQUEÑOS A PROPÓSITO.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, PARECÍAS COMPETITIVO MIENTRAS BASTABAN LOS DEDOS.",
                "result.mixed.oneWrong.mechanic.reading": "ESTABA ESCRITO DELANTE DE TI, {name}. DELANTE. DE. TI.",
                "result.mixed.oneWrong.mechanic.waiting": "TENÍAS QUE NO HACER NADA, {name}. POR FIN TU ESPECIALIDAD.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, ERA CUESTIÓN DE TIEMPO. Y LO PERDISTE.",
                "result.mixed.oneWrong.mechanic.memory": "ERA UNA SOLA COSA, {name}. NO UNA NOVELA ENTERA.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, ERA TU OTRA IZQUIERDA.",
                "result.mixed.oneWrong.mechanic.perception": "ESTABA ANTE TUS OJOS, {name}. TÚ TAMBIÉN, POR DESGRACIA.",
            ],
            "pt": [
                "result.mixed.oneWrong.named": "CALMA, {name}. DEPOIS EU EXPLICO. PROMETO.",
                "result.player.stillZero": "{name}, GANHA QUEM FAZ MAIS PONTOS. OU PELO MENOS ALGUM PONTO.",
                "result.player.firstPointLate": "AH, ENTÃO PERCEBESTE QUE ISTO ERA UMA COMPETIÇÃO, {name}?",
                "result.player.wrongStreak3": "{name}, QUERES TELEFONAR A UM AMIGO OU CONSEGUES FALHAR SOZINHO?",
                "result.player.lss.lastLife": "{name}, RESTA-TE UMA VIDA. TENTA NÃO DESPERDIÇAR ESTA TAMBÉM.",
                "result.player.lss.losingLives": "{name}, VIDAS NÃO SÃO PONTOS. ELAS ACABAM MESMO.",
                "result.mixed.oneWrong.mechanic.button": "ERA UM BOTÃO, {name}. UM.",
                "result.mixed.oneWrong.mechanic.math": "{name}, USÁMOS NÚMEROS PEQUENOS DE PROPÓSITO.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, PARECIAS COMPETITIVO ENQUANTO OS DEDOS CHEGAVAM.",
                "result.mixed.oneWrong.mechanic.reading": "ESTAVA ESCRITO À TUA FRENTE, {name}. À. TUA. FRENTE.",
                "result.mixed.oneWrong.mechanic.waiting": "TINHAS DE NÃO FAZER NADA, {name}. FINALMENTE A TUA ESPECIALIDADE.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, ERA UMA QUESTÃO DE TEMPO. E TU DESPERDIÇASTE-O.",
                "result.mixed.oneWrong.mechanic.memory": "ERA UMA COISA SÓ, {name}. NÃO UM ROMANCE INTEIRO.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, ERA A TUA OUTRA ESQUERDA.",
                "result.mixed.oneWrong.mechanic.perception": "ESTAVA DIANTE DOS TEUS OLHOS, {name}. TU TAMBÉM, INFELIZMENTE.",
            ],
            "de": [
                "result.mixed.oneWrong.named": "GANZ RUHIG, {name}. ICH ERKLÄRE ES DIR SPÄTER. VERSPROCHEN.",
                "result.player.stillZero": "{name}, MAN GEWINNT MIT MEHR PUNKTEN. ODER WENIGSTENS MIT EINEM.",
                "result.player.firstPointLate": "ACH, DU HAST GEMERKT, DASS DAS EIN WETTBEWERB IST, {name}?",
                "result.player.wrongStreak3": "{name}, WILLST DU JEMANDEN ANRUFEN ODER SCHAFFST DU DAS ALLEIN?",
                "result.player.lss.lastLife": "{name}, EIN LEBEN NOCH. VERSCHWENDE DAS BITTE NICHT AUCH.",
                "result.player.lss.losingLives": "{name}, LEBEN SIND KEINE PUNKTE. DIE GEHEN WIRKLICH AUS.",
                "result.mixed.oneWrong.mechanic.button": "ES WAR EIN KNOPF, {name}. EINER.",
                "result.mixed.oneWrong.mechanic.math": "{name}, WIR HABEN EXTRA KLEINE ZAHLEN GENOMMEN.",
                "result.mixed.oneWrong.mechanic.counting": "{name}, SOLANGE DIE FINGER REICHTEN, SAHST DU KONKURRENZFÄHIG AUS.",
                "result.mixed.oneWrong.mechanic.reading": "ES STAND VOR DIR, {name}. DIREKT. VOR. DIR.",
                "result.mixed.oneWrong.mechanic.waiting": "DU SOLLTEST NICHTS TUN, {name}. ENDLICH DEIN SPEZIALGEBIET.",
                "result.mixed.oneWrong.mechanic.timing": "{name}, ES WAR EINE FRAGE DER ZEIT. DU HAST SIE VERSCHWENDET.",
                "result.mixed.oneWrong.mechanic.memory": "ES WAR EINE SACHE, {name}. KEIN GANZER ROMAN.",
                "result.mixed.oneWrong.mechanic.direction": "{name}, DAS WAR DEIN ANDERES LINKS.",
                "result.mixed.oneWrong.mechanic.perception": "ES WAR DIREKT VOR DEINEN AUGEN, {name}. DU LEIDER AUCH.",
            ],
        ]
        let source = localized[locale] ?? localized["en"]!
        var result: [String: [PresenterLineBook.Line]] = Dictionary(uniqueKeysWithValues: source.map { key, text in
            (key, [PresenterLineBook.Line(id: "\(locale).\(key).0", text: text, intensity: .savage)])
        })
        let again = againTemplates[locale] ?? againTemplates["en"]!
        result["result.player.again"] = again.enumerated().map {
            PresenterLineBook.Line(id: "\(locale).result.player.again.\($0.offset)", text: $0.element, intensity: .savage)
        }
        if locale == "it" {
            result["result.mixed.oneWrong.mechanic.button", default: []].append(
                .init(id: "it.button.tutorial", text: "{name}, NON PENSAVO SERVISSE UN TUTORIAL PER PREMERE UN BOTTONE.", intensity: .savage)
            )
            result["result.mixed.oneWrong.mechanic.math", default: []].append(
                .init(id: "it.math.elementari", text: "{name}, QUESTA ERA LETTERALMENTE UNA DOMANDA DELLE ELEMENTARI.", intensity: .savage)
            )
            result["result.player.wrongStreak3", default: []].append(contentsOf: [
                PresenterLineBook.Line(id: "it.streak.pubblico", text: "TI SERVE L'AIUTO DEL PUBBLICO, {name}? PERCHÉ QUI SIAMO ALLA DISPERAZIONE.", intensity: .savage),
                PresenterLineBook.Line(id: "it.streak.notaio", text: "SE AVESSIMO UN NOTAIO, STAREBBE GIÀ CHIAMANDO PER SUGGERIRTI, {name}.", intensity: .savage),
            ])
            result["result.player.firstPointLate", default: []].append(
                .init(id: "it.firstPoint.regia", text: "DALLA REGIA DICONO CHE {name} ERA QUI DALL'INIZIO. NON CE N'ERAVAMO ACCORTI. FORSE NEANCHE LUI.", intensity: .savage)
            )
        }
        return result
    }

    /// Escalation for a player the host already roasted this match: the
    /// callback replaces a second use of a spent joke.
    private static let againTemplates: [String: [String]] = [
        "it": [
            "ANCORA TU, {name}? ORMAI È UN APPUNTAMENTO FISSO.",
            "{name}, DI NUOVO. A QUESTO PUNTO È UNO STILE.",
            "LA REGIA HA SMESSO DI CONTARE GLI ERRORI DI {name}. HA FINITO I FOGLI.",
        ],
        "en": [
            "YOU AGAIN, {name}? IT'S BECOMING A TRADITION.",
            "{name}, AGAIN. AT THIS POINT IT'S A STYLE.",
            "THE CONTROL ROOM STOPPED COUNTING {name}'S MISTAKES. THEY RAN OUT OF PAPER.",
        ],
        "fr": [
            "ENCORE TOI, {name} ? ÇA DEVIENT UNE TRADITION.",
            "{name}, ENCORE. À CE STADE, C'EST UN STYLE.",
            "LA RÉGIE A ARRÊTÉ DE COMPTER LES ERREURS DE {name}. PLUS DE PAPIER.",
        ],
        "es": [
            "¿OTRA VEZ TÚ, {name}? ESTO YA ES UNA TRADICIÓN.",
            "{name}, OTRA VEZ. A ESTAS ALTURAS ES UN ESTILO.",
            "EN CONTROL YA NO CUENTAN LOS ERRORES DE {name}. SE QUEDARON SIN PAPEL.",
        ],
        "pt": [
            "OUTRA VEZ TU, {name}? JÁ É UMA TRADIÇÃO.",
            "{name}, OUTRA VEZ. A ESTA ALTURA É UM ESTILO.",
            "A REALIZAÇÃO DEIXOU DE CONTAR OS ERROS DE {name}. ACABOU-SE O PAPEL.",
        ],
        "de": [
            "SCHON WIEDER DU, {name}? DAS WIRD LANGSAM TRADITION.",
            "{name}, SCHON WIEDER. INZWISCHEN IST DAS EIN STIL.",
            "DIE REGIE ZÄHLT DIE FEHLER VON {name} NICHT MEHR. DAS PAPIER IST AUS.",
        ],
    ]

    private static func combinedTitleTemplates(locale: String) -> [String: [PresenterLineBook.Line]] {
        let copy: [String]
        switch locale {
        case "it": copy = ["{name}, UN ALTRO PUNTO. DA ORA SEI {title}.", "{name}, TRE DI FILA. DA ORA SEI {title}."]
        case "fr": copy = ["{name}, ENCORE UN POINT. TU ES DÉSORMAIS {title}.", "{name}, TROIS DE SUITE. TU ES DÉSORMAIS {title}."]
        case "es": copy = ["{name}, OTRO PUNTO. AHORA ERES {title}.", "{name}, TRES SEGUIDAS. AHORA ERES {title}."]
        case "pt": copy = ["{name}, MAIS UM PONTO. AGORA ÉS {title}.", "{name}, TRÊS SEGUIDAS. AGORA ÉS {title}."]
        case "de": copy = ["{name}, NOCH EIN PUNKT. AB JETZT BIST DU {title}.", "{name}, DREIMAL IN FOLGE. AB JETZT BIST DU {title}."]
        default: copy = ["{name}, ANOTHER POINT. YOU ARE NOW {title}.", "{name}, THREE IN A ROW. YOU ARE NOW {title}."]
        }
        return [
            "result.title.king.named": [.init(id: "\(locale).result.title.king.0", text: copy[0])],
            "result.title.doesNotRead.named": [.init(id: "\(locale).result.title.doesNotRead.0", text: copy[1], intensity: .savage)],
        ]
    }
}

/// Pure presenter director. It consumes verified match facts only and emits
/// short cues; audio/network concerns live above it. Copy comes from
/// `lineBook`, which the host may replace with a newer synced pack.
///
/// Every cue passes the repetition guard (`PresenterLineHistory`): a beat
/// whose every line is cooling down or already spent returns no cue at all.
public final class PresenterEngine {
    public var intensity: PresenterIntensity
    public var lineBook: PresenterLineBook
    private var history = PresenterLineHistory()
    private var roastedThisMatch: Set<String> = []
    private var wins: [String: Int] = [:]
    private var wrongStreak: [String: Int] = [:]
    private var titleByPlayer: [String: PresenterLineBook.Title] = [:]
    private var roundsPlayed = 0
    private var lastOutcome: String?
    private var outcomeStreak = 0
    private var sequence = 0

    public init(intensity: PresenterIntensity = .neutral, lineBook: PresenterLineBook = .builtIn) {
        self.intensity = intensity
        self.lineBook = lineBook
    }

    /// Clears the in-match story ledger. Careers already persisted are kept.
    public func beginMatch() {
        wins = [:]
        wrongStreak = [:]
        titleByPlayer = [:]
        roundsPlayed = 0
        lastOutcome = nil
        outcomeStreak = 0
        roastedThisMatch = []
        history.beginMatch()
    }

    public func lobbyEmpty() -> PresenterCue? {
        history.advance()
        return universal(keys: ["lobby.empty"], kind: .lobby, expiry: .whileLobby)
    }

    public func roundResult(_ fact: PresenterRoundFact, players: [PresenterPlayer]) -> [PresenterCue] {
        history.advance()
        let previousWins = wins
        for player in players {
            if fact.correctPlayerIds.contains(player.id) {
                wrongStreak[player.id] = 0
                wins[player.id, default: 0] += 1
            } else if fact.wrongPlayerIds.contains(player.id) {
                wrongStreak[player.id, default: 0] += 1
            }
        }

        let keys = roundResultKeys(fact)
        let expiry = PresenterExpiry.throughResults(roundId: fact.roundId)
        var earnedTitle: (player: PresenterPlayer, title: String, key: String)?
        if let leader = players.first(where: { wins[$0.id, default: 0] >= 4 }), titleByPlayer[leader.id] == nil {
            titleByPlayer[leader.id] = .king
            earnedTitle = (leader, lineBook.title(.king), "king")
        } else if intensity == .savage,
                  let target = players.first(where: { wrongStreak[$0.id, default: 0] >= 3 }),
                  titleByPlayer[target.id] == nil {
            titleByPlayer[target.id] = .doesNotRead
            earnedTitle = (target, lineBook.title(.doesNotRead), "doesNotRead")
        }

        if let earnedTitle, let cue = combinedTitleCue(player: earnedTitle.player, title: earnedTitle.title, key: earnedTitle.key, players: players, expiry: expiry)
            ?? namedCue(player: earnedTitle.player, title: earnedTitle.title, factKey: "title.\(earnedTitle.key)", expiry: expiry) {
            return [cue]
        }
        let cue = personalizedResultCue(fact, players: players, previousWins: previousWins, expiry: expiry)
            ?? universal(keys: keys, kind: .roundResult, expiry: expiry)
        return cue.map { [$0] } ?? []
    }

    /// Line-book keys for a round result, most specific first. The backend
    /// can cover a narrower case by publishing lines under one of these keys;
    /// the engine falls back to the generic outcome when it has none. New
    /// *facts* still need an app release — this is the whole vocabulary.
    func roundResultKeys(_ fact: PresenterRoundFact) -> [String] {
        let base: String
        if fact.correctPlayerIds.isEmpty { base = "result.everyoneWrong" }
        else if fact.wrongPlayerIds.isEmpty { base = "result.everyoneCorrect" }
        else { base = "result.mixed" }
        roundsPlayed += 1
        outcomeStreak = lastOutcome == base ? outcomeStreak + 1 : 1
        lastOutcome = base

        var keys: [String] = []
        if outcomeStreak >= 3 { keys.append("\(base).streak3") }
        if base == "result.mixed" {
            if fact.wrongPlayerIds.count == 1 { keys.append("result.mixed.oneWrong") }
            if fact.correctPlayerIds.count == 1 { keys.append("result.mixed.oneCorrect") }
        }
        if let mechanic = fact.mechanic { keys.append("\(base).mechanic.\(mechanic.rawValue)") }
        if roundsPlayed == 1 { keys.append("\(base).firstRound") }
        keys.append(base)
        return keys
    }

    public func gameEnd(winner: PresenterPlayer?) -> PresenterCue? {
        history.advance()
        if let winner, let spoken = disambiguatedName(for: winner, among: [winner]),
           let text = render(template: "gameEnd.named", name: spoken) {
            return PresenterCue(id: nextId("gameEnd.named"), kind: .gameEnd, text: text, targetPlayerId: winner.id, expiry: .whileGameEnd, cacheable: true)
        }
        return universal(keys: ["gameEnd"], kind: .gameEnd, expiry: .whileGameEnd)
    }

    /// The title a player earned this match, as a key: careers store it
    /// language-neutral and `returningCue` words it in the current locale.
    public func currentTitle(for playerId: String) -> PresenterLineBook.Title? { titleByPlayer[playerId] }

    /// Named lines the next round's result could need, most likely first,
    /// rendered exactly as `roundResult` would say them. Read-only: it never
    /// spends a joke. The host prefetches their audio during the round so a
    /// named line does not miss its slot waiting for live speech.
    public func likelyNamedLines(
        challengeId: String?,
        mode: PresenterGameMode,
        livesByPlayer: [String: Int] = [:],
        players: [PresenterPlayer]
    ) -> [String] {
        let nextRound = roundsPlayed + 1
        let mechanic = challengeId.flatMap(PresenterMechanic.init(challengeId:)).map { ".mechanic.\($0.rawValue)" } ?? ""
        var titles: [String] = []
        var perPlayer: [[String]] = []
        for player in players {
            guard let name = disambiguatedName(for: player, among: players) else { continue }
            let wins = wins[player.id, default: 0]
            let streak = wrongStreak[player.id, default: 0]
            if wins == 3, titleByPlayer[player.id] == nil {
                titles += candidates(keys: ["result.title.king.named"], name: name, title: lineBook.title(.king))
            }
            guard intensity == .savage else { continue }
            if streak == 2, titleByPlayer[player.id] == nil {
                titles += candidates(keys: ["result.title.doesNotRead.named"], name: name, title: lineBook.title(.doesNotRead))
            }
            var lines: [String] = []
            if mode == .battle, wins == 0, nextRound >= 4 {
                lines += candidates(keys: ["result.player.firstPointLate\(mechanic)", "result.player.firstPointLate"], name: name)
            }
            if mode == .battle, wins == 0, nextRound >= 3 {
                lines += candidates(keys: ["result.player.stillZero\(mechanic)", "result.player.stillZero"], name: name)
            }
            if mode == .lastStupidStanding, livesByPlayer[player.id] == 2 {
                lines += candidates(keys: ["result.player.lss.lastLife"], name: name)
            }
            if mode == .lastStupidStanding, streak >= 1 {
                lines += candidates(keys: ["result.player.lss.losingLives"], name: name)
            }
            if players.count > 1 {
                lines += candidates(keys: ["result.mixed.oneWrong\(mechanic)", "result.mixed.oneWrong.named"], name: name)
            }
            if streak == 2 {
                lines += candidates(keys: ["result.player.wrongStreak3\(mechanic)", "result.player.wrongStreak3"], name: name)
            }
            if roastedThisMatch.contains(player.id) {
                lines += candidates(keys: ["result.player.again"], name: name)
            }
            perPlayer.append(lines)
        }
        // Round-robin so a small prefetch budget covers every player's most
        // likely line before anyone's second choice.
        var ordered = titles
        for depth in 0..<(perPlayer.map(\.count).max() ?? 0) {
            ordered += perPlayer.compactMap { depth < $0.count ? $0[depth] : nil }
        }
        var seen: Set<String> = []
        return ordered.filter { seen.insert($0).inserted }
    }

    public func returningCue(player: PresenterPlayer, title key: PresenterLineBook.Title) -> PresenterCue? {
        history.advance()
        let title = lineBook.title(key)
        let name = player.spokenName?.uppercased()
        guard let text = render(template: name == nil ? "lobby.returning.anonymous" : "lobby.returning.named", name: name, title: title) else { return nil }
        return PresenterCue(id: nextId("lobby.returning"), kind: .lobby, text: text, targetPlayerId: player.id, expiry: .whileLobby, cacheable: name != nil)
    }

    public func crownWinner(_ playerId: String) {
        titleByPlayer[playerId] = .kingUndisputed
    }

    public func disambiguatedName(for player: PresenterPlayer, among players: [PresenterPlayer]) -> String? {
        guard let base = player.spokenName else { return nil }
        let matches = players.filter { $0.spokenName?.localizedCaseInsensitiveCompare(base) == .orderedSame }
        guard matches.count > 1 else { return base.uppercased() }
        guard let index = matches.firstIndex(where: { $0.id == player.id }) else { return base.uppercased() }
        let labels: [String]
        switch lineBook.locale {
        case "en": labels = ["THE REAL", "THE OTHER", "THE OTHER OTHER"]
        case "fr": labels = ["LE VRAI", "L'AUTRE", "L'AUTRE AUTRE"]
        case "es": labels = ["EL VERDADERO", "EL OTRO", "EL OTRO OTRO"]
        case "pt": labels = ["O VERDADEIRO", "O OUTRO", "O OUTRO OUTRO"]
        case "de": labels = ["DER ECHTE", "DER ANDERE", "DER ANDERE ANDERE"]
        default: labels = ["IL VERO", "L'ALTRO", "L'ALTRO ALTRO"]
        }
        return "\(labels[min(index, 2)]) \(base.uppercased())"
    }

    private func namedCue(player: PresenterPlayer, title: String, factKey: String, expiry: PresenterExpiry) -> PresenterCue? {
        let name = player.spokenName?.uppercased()
        guard let text = render(template: name == nil ? "title.anonymous" : "title.named", name: name, title: title) else { return nil }
        return PresenterCue(id: nextId(factKey), kind: .title, text: text, targetPlayerId: player.id, expiry: expiry, cacheable: name != nil)
    }

    private func personalizedResultCue(
        _ fact: PresenterRoundFact,
        players: [PresenterPlayer],
        previousWins: [String: Int],
        expiry: PresenterExpiry
    ) -> PresenterCue? {
        guard intensity == .savage else { return nil }
        let mechanic = fact.mechanic.map { ".mechanic.\($0.rawValue)" } ?? ""

        if fact.mode == .battle, roundsPlayed >= 4,
           let target = players.first(where: {
               fact.correctPlayerIds.contains($0.id) && previousWins[$0.id, default: 0] == 0
           }),
           let cue = resultCue(player: target, among: players, keys: [
               "result.player.firstPointLate\(mechanic)",
               "result.player.firstPointLate",
           ], expiry: expiry) { return cue }

        if fact.mode == .battle, roundsPlayed >= 3,
           let target = players.first(where: {
               fact.wrongPlayerIds.contains($0.id) && wins[$0.id, default: 0] == 0
           }),
           let cue = resultCue(player: target, among: players, keys: [
               "result.player.stillZero\(mechanic)",
               "result.player.stillZero",
           ], expiry: expiry) { return cue }

        if fact.mode == .lastStupidStanding,
           let target = players.first(where: {
               fact.wrongPlayerIds.contains($0.id) && fact.remainingLivesByPlayer[$0.id] == 1
           }), let cue = resultCue(player: target, among: players, keys: [
               "result.player.lss.lastLife",
           ], expiry: expiry) { return cue }

        if fact.mode == .lastStupidStanding,
           let target = players.first(where: {
               fact.wrongPlayerIds.contains($0.id) && wrongStreak[$0.id, default: 0] >= 2
           }), let cue = resultCue(player: target, among: players, keys: [
               "result.player.lss.losingLives",
           ], expiry: expiry) { return cue }

        if fact.wrongPlayerIds.count == 1,
           let target = players.first(where: { $0.id == fact.wrongPlayerIds[0] }),
           let cue = resultCue(player: target, among: players, keys: [
               "result.mixed.oneWrong\(mechanic)",
               "result.mixed.oneWrong.named",
           ], expiry: expiry) { return cue }

        if let target = players.first(where: {
            fact.wrongPlayerIds.contains($0.id) && wrongStreak[$0.id, default: 0] >= 3
        }), let cue = resultCue(player: target, among: players, keys: [
            "result.player.wrongStreak3\(mechanic)",
            "result.player.wrongStreak3",
        ], expiry: expiry) { return cue }
        return nil
    }

    private func combinedTitleCue(player: PresenterPlayer, title: String, key: String, players: [PresenterPlayer], expiry: PresenterExpiry) -> PresenterCue? {
        guard let name = disambiguatedName(for: player, among: players),
              let text = render(template: "result.title.\(key).named", name: name, title: title) else { return nil }
        return PresenterCue(id: nextId("result.title.\(key)"), kind: .title, text: text, targetPlayerId: player.id, expiry: expiry, cacheable: true)
    }

    /// Tries [keys] in order; a player already roasted this match also gets
    /// the escalating callback (`result.player.again`) before the engine
    /// moves on to another fact or the room-wide line.
    private func resultCue(player: PresenterPlayer, among players: [PresenterPlayer], keys: [String], expiry: PresenterExpiry) -> PresenterCue? {
        guard let name = disambiguatedName(for: player, among: players) else { return nil }
        let ladder = roastedThisMatch.contains(player.id) ? keys + ["result.player.again"] : keys
        for key in ladder {
            if let text = render(template: key, name: name) {
                roastedThisMatch.insert(player.id)
                return PresenterCue(id: nextId(key), kind: .roundResult, text: text, targetPlayerId: player.id, expiry: expiry, cacheable: true)
            }
        }
        return nil
    }

    /// Walks the specificity ladder: the first key with a line that is not
    /// cooling down wins, so a spent specific joke falls back to a fresher
    /// generic one. The in-code baseline is used only when the active book
    /// has no line for any key (a synced book's removals stay removed).
    private func universal(keys: [String], kind: PresenterCueKind, expiry: PresenterExpiry) -> PresenterCue? {
        var pools = keys.map { lineBook.variants(for: $0, intensity: intensity) }
        if pools.allSatisfy(\.isEmpty) {
            let baseline = PresenterLineBook.builtIn(locale: lineBook.locale)
            pools = keys.map { baseline.variants(for: $0, intensity: intensity) }
        }
        for variants in pools where !variants.isEmpty {
            let offset = sequence % variants.count
            let rotated = variants.indices.map { variants[($0 + offset) % variants.count] }
            guard let line = rotated.first(where: { history.allows($0.text, oncePerMatch: false) }) else { continue }
            history.record(line.text)
            sequence += 1
            return PresenterCue(id: "pack.\(line.id)", kind: kind, text: line.text, expiry: expiry, cacheable: true, clip: line.clip)
        }
        return nil
    }

    /// Fills the first variant of [key] whose joke is neither cooling down
    /// nor already told this match (whoever it was aimed at), rotating the
    /// starting variant. Nil when the key is missing or fully spent.
    private func render(template key: String, name: String? = nil, title: String? = nil) -> String? {
        let options = tellable(template: key, name: name, title: title)
        guard !options.isEmpty else { return nil }
        let pick = options[sequence % options.count]
        history.record(pick.joke)
        return pick.text
    }

    /// What `render` could say for the first of [keys] that has anything
    /// left, without spending it.
    private func candidates(keys: [String], name: String, title: String? = nil) -> [String] {
        keys.lazy.map { self.tellable(template: $0, name: name, title: title).map(\.text) }.first { !$0.isEmpty } ?? []
    }

    /// Allowed, unspent variants of [key] in book order: `joke` is the copy
    /// the history remembers (title filled, `{name}` literal), `text` the
    /// line as spoken.
    private func tellable(template key: String, name: String?, title: String?) -> [(joke: String, text: String)] {
        var variants = lineBook.templateVariants(for: key, intensity: intensity)
        if variants.isEmpty {
            variants = PresenterLineBook.builtIn(locale: lineBook.locale).templateVariants(for: key, intensity: intensity)
        }
        return variants.compactMap { variant in
            var joke = variant.text
            if let title { joke = joke.replacingOccurrences(of: "{title}", with: title) }
            guard history.allows(joke, oncePerMatch: true) else { return nil }
            let text = name.map { joke.replacingOccurrences(of: "{name}", with: $0) } ?? joke
            return text.contains("{") ? nil : (joke, text)
        }
    }

    private func nextId(_ prefix: String) -> String {
        sequence += 1
        return "\(prefix).\(sequence)"
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
