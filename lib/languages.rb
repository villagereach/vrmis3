# -*- coding: utf-8 -*-
class Languages
  # Language names, in their native languages, taken from the Unicode CLDR project
  @@native_languages = {
    :aa        => "Qafar",              # Afar
    :af        => "Afrikaans",          # Afrikaans
    :am        => "አማርኛ",               # Amharic
    :ar        => "العربية",            # Arabic
    :as        => "অসমীয়া",            # Assamese
    :az        => "azərbaycanca",       # Azerbaijani
    :be        => "беларуская",         # Belarusian
    :bg        => "български",          # Bulgarian
    :bn        => "বাংলা",              # Bengali
    :bo        => "པོད་སྐད་",           # Tibetan
    :bs        => "bosanski",           # Bosnian
    :byn       => "ብሊን",                # Blin
    :ca        => "català",             # Catalan
    :cs        => "čeština",            # Czech
    :cy        => "Cymraeg",            # Welsh
    :da        => "dansk",              # Danish
    :de        => "Deutsch",            # German
    :dv        => "ދިވެހިބަސް",         # Divehi
    :dz        => "རྫོང་ཁ",             # Dzongkha
    :el        => "Ελληνικά",           # Greek
    :en        => "English",            # English
    :eo        => "esperanto",          # Esperanto
    :es        => "español",            # Spanish
    :et        => "eesti",              # Estonian
    :eu        => "euskara",            # Basque
    :fa        => "فارسی",              # Persian
    :fi        => "suomi",              # Finnish
    :fil       => "Filipino",           # Filipino
    :fo        => "føroyskt",           # Faroese
    :fr        => "français",           # French
    :fur       => "furlan",             # Friulian
    :ga        => "Gaeilge",            # Irish
    :gez       => "ግዕዝኛ",               # Geez
    :gl        => "galego",             # Galician
    :gsw       => "Schwiizertüütsch",   # Swiss German
    :gu        => "ગુજરાતી",            # Gujarati
    :gv        => "Gaelg",              # Manx
    :ha        => "Haoussa",            # Hausa
    :haw       => "ʻōlelo Hawaiʻi",     # Hawaiian
    :he        => "עברית",              # Hebrew
    :hi        => "हिन्दी",             # Hindi
    :hr        => "hrvatski",           # Croatian
    :hu        => "magyar",             # Hungarian
    :hy        => "Հայերէն",            # Armenian
    :ia        => "interlingua",        # Interlingua
    :id        => "Bahasa Indonesia",   # Indonesian
    :ii        => "ꆈꌠꉙ",                # Sichuan Yi
    :is        => "íslenska",           # Icelandic
    :it        => "italiano",           # Italian
    :iu        => "ᐃᓄᒃᑎᑐᑦ ᑎᑎᕋᐅᓯᖅ",      # Inuktitut
    :ja        => "日本語",             # Japanese
    :ka        => "ქართული",            # Georgian
    :kk        => "Қазақ",              # Kazakh
    :kl        => "kalaallisut",        # Kalaallisut
    :km        => "ភាសាខ្មែរ",          # Khmer
    :kn        => "ಕನ್ನಡ",              # Kannada
    :ko        => "한국어",             # Korean
    :kok       => "कोंकणी",             # Konkani
    :kw        => "kernewek",           # Cornish
    :ky        => "Кыргыз",             # Kirghiz
    :ln        => "lingála",            # Lingala
    :lo        => "ລາວ",                # Lao
    :lt        => "lietuvių",           # Lithuanian
    :lv        => "latviešu",           # Latvian
    :mk        => "македонски",         # Macedonian
    :ml        => "മലയാളം",             # Malayalam
    :mn        => "монгол",             # Mongolian
    :mr        => "मराठी",              # Marathi
    :ms        => "Bahasa Melayu",      # Malay
    :mt        => "Malti",              # Maltese
    :my        => "ဗမာ",                # Burmese
    :nb        => "norsk bokmål",       # Norwegian Bokmål
    :nds       => "Plattdüütsch",       # Low German
    :ne        => "नेपाली",             # Nepali
    :nl        => "Nederlands",         # Dutch
    :nn        => "nynorsk",            # Norwegian Nynorsk
    :nr        => "isiNdebele",         # South Ndebele
    :nso       => "Sesotho sa Leboa",   # Northern Sotho
    :oc        => "occitan",            # Occitan
    :om        => "Oromoo",             # Oromo
    :or        => "ଓଡ଼ିଆ",              # Oriya
    :pa        => "ਪੰਜਾਬੀ",             # Punjabi
    :pl        => "polski",             # Polish
    :ps        => "پښتو",               # Pashto
    :pt        => "português",          # Portuguese
    :ro        => "română",             # Romanian
    :ru        => "русский",            # Russian
    :sa        => "संस्कृत भाषा",       # Sanskrit
    :se        => "davvisámegiella",    # Northern Sami
    :si        => "සිංහල",              # Sinhala
    :sid       => "Sidaamu Afo",        # Sidamo
    :sk        => "slovenčina",         # Slovak
    :sl        => "slovenščina",        # Slovenian
    :so        => "Soomaali",           # Somali
    :sq        => "shqipe",             # Albanian
    :sr        => "Српски",             # Serbian
    :ss        => "Siswati",            # Swati
    :st        => "Sesotho",            # Southern Sotho
    :sv        => "svenska",            # Swedish
    :sw        => "Kiswahili",          # Swahili
    :syr       => "ܣܘܪܝܝܐ",             # Syriac
    :ta        => "தமிழ்",              # Tamil
    :te        => "తెలుగు",             # Telugu
    :th        => "ไทย",                # Thai
    :ti        => "ትግርኛ",               # Tigrinya
    :tig       => "ትግረ",                # Tigre
    :tn        => "Setswana",           # Tswana
    :to        => "lea fakatonga",      # Tonga
    :tr        => "Türkçe",             # Turkish
    :ts        => "Xitsonga",           # Tsonga
    :tt        => "Татар",              # Tatar
    :uk        => "українська",         # Ukrainian
    :ur        => "اردو",               # Urdu
    :uz        => "Ўзбек",              # Uzbek
    :ve        => "Tshivenḓa",          # Venda
    :vi        => "Tiếng Việt",         # Vietnamese
    :wal       => "ወላይታቱ",              # Walamo
    :xh        => "isiXhosa",           # Xhosa
    :yo        => "Yorùbá",             # Yoruba
    :"zh-Hant" => "繁體中文",           # Traditional Chinese
    :zh        => "中文",               # Chinese
    :zu        => "isiZulu"             # Zulu
  }
  cattr_reader :native_languages
end
