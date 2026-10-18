import Foundation

/// A short reference of widely used Chicago-style conventions, written for this
/// project in our own words. It is NOT text from The Chicago Manual of Style,
/// which is copyrighted, and it carries no section numbers. For authoritative
/// rulings, add a licensed copy of CMOS to the app's library.
public enum BuiltInGuide {

    public static let id = UUID(uuidString: "6C6A1F2E-0C1B-4B7E-9D7A-5A1E2C0F9B01")!
    public static let title = "Chicago Quick Reference"

    public static func guide(isEnabled: Bool) -> StyleGuide {
        let chunks = self.chunks
        return StyleGuide(
            id: id, title: title, sourceFileName: nil, isBuiltIn: true, isEnabled: isEnabled,
            addedAt: Date(timeIntervalSince1970: 0), chunkCount: chunks.count,
            wordCount: chunks.reduce(0) { $0 + Chunker.wordCount($1.text) })
    }

    /// One passage per topic, so search results stay focused.
    public static var chunks: [GuideChunk] {
        let topics = text.components(separatedBy: "\n## ").dropFirst()
        return topics.enumerated().map { index, topic in
            let lines = topic.components(separatedBy: "\n")
            let heading = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let body = lines.dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return GuideChunk(id: index, heading: heading, location: nil, text: heading + ". " + body)
        }
    }

    public static let text = """
        # Chicago Quick Reference

        ## Serial comma
        Use a comma before the conjunction in a series of three or more items: "red, white, and blue." This is often called the Oxford or serial comma. Chicago recommends it consistently because it prevents ambiguity ("I thanked my parents, Ayn Rand, and God").

        ## Commas between independent clauses
        Put a comma before a coordinating conjunction (and, but, or, nor, for, so, yet) that joins two independent clauses: "The reviewers agreed, but the editor hesitated." The comma may be omitted when both clauses are very short and closely linked. Do not use a comma alone to join two independent clauses (a comma splice); use a semicolon, a conjunction, or two sentences.

        ## Commas after introductory elements
        A comma usually follows an introductory phrase or dependent clause, especially a long one: "After the manuscript was accepted, the author revised the notes." It may be omitted after a short introductory phrase if no misreading results: "In 2020 the journal moved online."

        ## Restrictive and nonrestrictive clauses (that vs. which)
        A restrictive clause identifies which thing is meant and takes no commas; Chicago recommends "that" for it: "The essay that won the prize appears in issue 3." A nonrestrictive clause adds extra information, is set off by commas, and uses "which": "The essay, which won the prize, appears in issue 3." "Who" is used for people in both kinds of clause.

        ## Commas with appositives, dates, and places
        Set off nonrestrictive appositives with commas ("Her editor, Ana Ruiz, approved it"), but not restrictive ones ("the poet Elizabeth Bishop"). In month-day-year dates, put commas after the day and after the year when the sentence continues: "On May 5, 2026, the issue appeared." With day-month-year order no commas are needed: "5 May 2026." Set off a state or country after a city: "Austin, Texas, is the venue." "Jr." and "III" need no commas.

        ## Semicolons
        Use a semicolon between independent clauses not joined by a conjunction: "The data were incomplete; the conclusions were tentative." Use it before conjunctive adverbs such as however, therefore, and indeed when they join clauses ("...; however, ..."). Use semicolons to separate items in a series when the items themselves contain commas.

        ## Colons
        A colon introduces an element that explains, illustrates, or amplifies what precedes it. After a colon, lowercase the first word unless it is a proper noun, or the colon introduces two or more complete sentences, a quotation, a speech in dialogue, or a direct question. Use one space after a colon. Do not place a colon between a verb or preposition and its object ("The contributors include Lee and Park," not "include: Lee and Park").

        ## Em dashes
        An em dash (—) marks a sudden break, an interruption, or an amplifying aside, and a pair can replace parentheses or commas: "The archive—long thought lost—was found in 1998." In Chicago style there are no spaces around an em dash. Use no more than one pair of em dashes in a sentence. A 2-em dash marks missing letters in a word; a 3-em dash can stand for a repeated author's name in a bibliography.

        ## En dashes
        An en dash (–) is longer than a hyphen and shorter than an em dash. Use it for ranges of numbers and dates, meaning "through": "pages 45–67," "1990–2005." Do not combine it with "from" or "between": write "from 1990 to 2005," not "from 1990–2005." Also use an en dash in a compound adjective when one element is an open compound or proper name: "post–World War II poetry," "New York–based publisher."

        ## Hyphens and compound modifiers
        Hyphenate a compound modifier that comes before a noun when it helps the reader: "a well-known author," "a twentieth-century novel." The same phrase after the noun is usually open: "The author is well known." Do not hyphenate an adverb ending in -ly: "a highly regarded study." Check a dictionary for permanent compounds, which may be closed (notebook), open (high school), or hyphenated (well-being).

        ## Prefixes
        Words formed with prefixes are generally closed, with no hyphen: nonprofit, coauthor, reelect, preexisting, antiwar, postwar, multilingual. Use a hyphen before a capitalized word or a numeral (un-American, pre-1950), to avoid doubled letters that confuse (anti-inflammatory), and to distinguish meanings (re-create versus recreate, re-cover versus recover).

        ## Numbers: spelling out or numerals
        In general (nontechnical) prose, Chicago spells out whole numbers from zero through one hundred and round multiples of those numbers: "twelve contributors," "forty-five pages," "two hundred years," "thirty thousand copies." Use numerals for other numbers: "324 pages." Always spell out a number that begins a sentence, or rephrase the sentence. Treat related numbers in the same passage consistently. Scientific and technical writing often uses numerals for all numbers 10 and above.

        ## Percentages, money, and measurements
        In general prose use numerals with the word "percent": "45 percent of respondents." The % symbol is used in scientific, statistical, and tabular material. Money follows the general number rule: "five dollars" but "$5.75" and "$1.2 million." With abbreviated units of measure always use numerals: "3 km," "12 mg."

        ## Dates, decades, and centuries
        Write full dates as "May 5, 2026" (or "5 May 2026"), never with ordinals such as "May 5th." Write decades without an apostrophe: "the 1990s," or "the nineties" spelled out. Spell out and lowercase centuries: "the twenty-first century," hyphenated when used as an adjective before a noun: "twenty-first-century fiction."

        ## Times of day
        Use numerals with a.m. and p.m.: "10:30 a.m.," "4:00 p.m." Spell out times with o'clock or in dialogue: "four o'clock." Use "noon" and "midnight" rather than 12:00 p.m. or 12:00 a.m.

        ## Inclusive numbers (page ranges)
        Chicago abbreviates the second number in a range as follows. If the first number is under 100, use all digits: 3–10, 71–72. If the first number is 100 or a multiple of 100, use all digits: 100–104, 1100–1113. If the first number is 101 through 109 in any hundred, give only the changed part: 101–8, 808–33, 1103–4. If the first number is 110 through 199 in any hundred, give at least two digits: 321–28, 498–532, 1087–89. When in doubt, all digits are acceptable.

        ## Ages and fractions
        Spell out ages in general prose following the number rule: "She was eighty-two." Hyphenate ages used as compound modifiers or nouns: "a five-year-old child," "a group of five-year-olds," but "the child is five years old." Spell out and hyphenate simple fractions: "two-thirds of the members," "one-half."

        ## Capitalization of titles (headline style)
        For titles of works in headline style, capitalize the first and last words and all major words: nouns, pronouns, verbs, adjectives, adverbs, and subordinating conjunctions (if, because, that, as). Lowercase articles (a, an, the), coordinating conjunctions (and, but, for, or, nor), "to" in infinitives, and prepositions regardless of length (of, in, between, through) unless they are the first or last word or used adverbially ("Look Up"). Capitalize the first word after a colon in a title or subtitle. Example: "The Uses of Memory in the Novels of Toni Morrison."

        ## Capitalizing hyphenated compounds in titles
        In headline-style titles, capitalize the first part of a hyphenated compound. Capitalize later parts too unless they are articles, prepositions, or coordinating conjunctions: "Self-Sustaining Systems," "Over-the-Counter Drugs." If the first part is a prefix that cannot stand alone (anti, pre, non, re), lowercase the second part unless it is a proper noun: "Anti-intellectualism," "Pre-Columbian."

        ## Sentence-style capitalization
        Sentence style capitalizes only the first word of a title or heading, the first word of a subtitle, and proper nouns. Many journals use sentence style for article titles in reference lists; follow the journal's house style when it differs from Chicago's default.

        ## Titles and offices of people
        Capitalize a civil, military, religious, or professional title when it comes directly before a name as part of the name: "President Lincoln," "Professor Ana Ruiz." Lowercase it when it follows the name or is used alone: "Abraham Lincoln, the president," "the professor said." Lowercase descriptive words that are not formal titles: "historian Ana Ruiz."

        ## Italics vs. quotation marks for titles
        Italicize titles of books, journals, magazines, newspapers, films, plays, long poems published as books, albums, and paintings. Use quotation marks for titles of articles, chapters, essays, short stories, short poems, songs, and unpublished works such as dissertations. Titles of book series and of scriptures (the Bible, the Qur'an) are capitalized but neither italicized nor quoted.

        ## Quotation marks and punctuation
        Use double quotation marks, and single quotation marks for a quotation within a quotation. In American Chicago style, periods and commas go inside closing quotation marks, even when they were not part of the original: 'He called it "a triumph."' Colons and semicolons go outside. Question marks and exclamation points go inside only if they belong to the quoted material: 'Did she say "never"?' versus 'He asked, "Is it finished?"'

        ## Block quotations
        Set off longer quotations as block quotations, commonly a hundred words or more, or at least six to eight lines, as well as any quotation of two or more paragraphs. A block quotation takes no quotation marks; quotation marks inside it are kept as double marks. Introduce it with a colon or appropriate punctuation and indent it from the left margin.

        ## Ellipses
        An ellipsis marks words omitted from a quotation. Chicago uses three spaced periods (. . .), with a space before and after, and nonbreaking spaces between the dots to keep them together. When the omission follows a complete sentence, keep that sentence's period and then add the three dots, making four dots. Ellipses are usually unnecessary at the beginning or end of a quotation, because a quotation is understood to be an extract.

        ## Brackets and sic
        Use square brackets for words the author or editor inserts into a quotation: "She [the editor] refused." To flag an error in the original, insert "sic," italicized, in roman brackets right after the error: [sic]. Use it sparingly; silently correcting obvious typographical errors is often acceptable.

        ## Possessives
        Form the possessive of most singular nouns by adding an apostrophe and s, including names and words ending in s: "the author's," "Kansas's," "Dickens's novels," "the witness's statement." Form the possessive of plural nouns ending in s with an apostrophe alone: "the authors' contributions," "the Joneses' house." For joint possession, make only the last name possessive: "Lee and Park's study"; for separate possession, make both possessive: "Lee's and Park's studies."

        ## Plurals of names, letters, and numbers
        Make proper names plural by adding s or es, never an apostrophe: "the Smiths," "the Joneses." Numerals and capital letters take a plain s: "the 1990s," "three Rs," "the As and Bs." Lowercase letters use an apostrophe and s for clarity: "mind your p's and q's." Abbreviations take a plain s: "PhDs," "URLs."

        ## Abbreviations and acronyms
        Chicago omits periods in abbreviations made of capital letters: US, UK, PhD, MA, BCE, CE, NASA. Use "US" mainly as an adjective ("US policy") and spell out "United States" as a noun in formal prose. Lowercase abbreviations usually take periods: a.m., p.m., e.g., i.e. Use e.g. and i.e. mainly in parentheses and notes, each followed by a comma; in running text prefer "for example" and "that is." Spell out an unfamiliar acronym at first use, with the acronym in parentheses.

        ## Italics for emphasis and foreign words
        Use italics sparingly for emphasis. Italicize isolated foreign words and phrases that are not in a standard English dictionary, but use roman type for familiar ones (ad hoc, et al., vis-à-vis). Proper names in other languages are never italicized. Words used as words may be italicized: "the word *style* has many senses."

        ## Lists
        Run-in lists within a sentence can be marked with numerals or letters in parentheses: "Applicants must submit (1) a cover letter, (2) a CV, and (3) a writing sample." Vertical lists should be introduced by a complete sentence ending in a colon, with items parallel in form. Items that are complete sentences begin with capitals and end with periods.

        ## Spacing
        Use one space, not two, after periods and colons. Use no space around em dashes and en dashes. Use a nonbreaking space between initials and between the dots of an ellipsis where possible.

        ## Singular they and inclusive language
        Recent Chicago guidance accepts singular "they" for a person whose gender is unknown or irrelevant, and for a person who uses "they" as their pronoun, while noting that some formal contexts still prefer rewording. Ways to avoid gendered generic pronouns include rewriting in the plural, using "the" instead of "his," or addressing the reader as "you." Use the names and pronouns people use for themselves.

        ## Common usage pairs
        affect (verb, to influence) / effect (noun, a result; verb, to bring about). fewer (countable: fewer errors) / less (mass: less time). comprise means "consist of": "The journal comprises four sections," not "is comprised of." lie (recline: lie, lay, lain) / lay (put: lay, laid, laid). farther (physical distance) / further (degree or extent). imply (suggest) / infer (deduce). among (three or more, or a mass) / between (two, or distinct items). who (subject) / whom (object). Use "toward," not "towards," in American English.

        ## Myths about grammar
        It is acceptable to begin a sentence with "and" or "but," to end a sentence with a preposition when it reads naturally ("the guide we relied on"), and to split an infinitive when that is clearer ("to fully understand"). Chicago treats "data" as either plural or singular (as a mass noun), depending on the field and house style; be consistent.

        ## Notes and bibliography system: overview
        Chicago offers two citation systems. The notes-bibliography system, common in the humanities and literary journals, uses numbered footnotes or endnotes plus an optional bibliography. The author-date system, common in the sciences and social sciences, uses parenthetical citations such as (Garcia 2019, 45) plus a reference list. Follow the journal's choice and do not mix systems.

        ## Note citations for books and articles
        A first full note for a book typically gives the author's name in normal order, the title in italics, the facts of publication in parentheses, and the page: "1. Ana Ruiz, *The Archive and the Lyric* (University of Example Press, 2021), 45." A journal article note gives the author, the article title in quotation marks, the journal title in italics, the volume, issue, year, page, and DOI if available: "2. Ana Ruiz, "Reading Margins," *Journal of Example Studies* 12, no. 3 (2020): 47, https://doi.org/..." Recent Chicago guidance makes the place of publication optional. (These names and titles are invented examples.)

        ## Shortened notes and ibid.
        After the first full citation, use a shortened note: the author's surname, a short form of the title (up to about four words), and the page: "3. Ruiz, *Archive and the Lyric*, 52." Chicago discourages "ibid." in favor of shortened notes, though it is still permitted. For four or more authors, a note gives the first author's name followed by "et al."

        ## Bibliography entries
        A bibliography entry inverts the first author's name and separates elements with periods: "Ruiz, Ana. *The Archive and the Lyric*. University of Example Press, 2021." Entries are alphabetized by the first author's surname. Bibliography entries list more author names than notes do before shortening to "et al."; check your edition or the journal's instructions for the exact cutoff.

        ## Author-date citations
        In the author-date system, cite in text as (Ruiz 2021, 45), with no comma between author and year and a comma before the page. For two authors: (Lee and Park 2019); for four or more: (Lee et al. 2019). In the reference list, the year comes right after the author's name: "Ruiz, Ana. 2021. *The Archive and the Lyric*. University of Example Press."
        """
}
