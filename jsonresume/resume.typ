// Resume data embedded directly in Typst
#let resume_data = (
  basics: (
    name: "Hanif Bin Ariffin",
    label: "Programmer",
    email: "hanif.ariffin.4326@gmail.com",
    phone: "+60 175930487",
    url: "https://hbina.github.io",
    summary: "Highly experienced and independent problem solver. Contributes to various widely used open source projects",
    location: (
      address: "Lot 633, Kampung Tok Dokang, Banggol",
      postalCode: "15350",
      city: "Kota Bharu",
      countryCode: "MY",
      region: "Kelantan"
    ),
    profiles: (
      (
        network: "Github",
        username: "hbina",
        url: "https://github.com/hbina"
      ),
      (
        network: "LinkedIn",
        username: "LinkedIn",
        url: "https://www.linkedin.com/in/hanif-bin-ariffin-73057a8b/"
      ),
      (
        network: "Personal Blog",
        username: "Personal Blog",
        url: "https://hbina.github.io/"
      )
    )
  ),
  work: (
    (
      name: "Setel",
      location: "Malaysia",
      position: "Fullstack developer",
      url: "https://www.setel.com/",
      startDate: "2020-12-01",
      endDate: "2022-02-01",
      summary: "Responsible for implementing and maintaining the loyalty system for self-checkout, the inventory and the store ordering system",
      highlights: ()
    ),
    (
      name: "Globelise",
      location: "Singapore",
      position: "Senior Fullstack Developer",
      url: "https://www.globelise.com/",
      startDate: "2022-02-01",
      endDate: "2022-07-01",
      summary: "Designed and implemented the backend system for a global hiring management system and 3rd party payroll integrations.",
      highlights: ()
    ),
    (
      name: "Confinex Technologies",
      location: "Pulau Pinang",
      position: "Software Developer",
      url: "https://confinex.com/",
      startDate: "2023-12-31",
      endDate: "",
      summary: "Help develop and maintain an entire trading infrastructure stack from market data all the way to post-processing to sending orders",
      highlights: (
        "Developed sub-microsecond market data processing library",
        "Used kernel bypass for packet filtering",
        "Developed automations to process market data",
        "Developed risk management and order sending system",
      )
    )
  ),
  volunteer: (
    (
      organization: "Godot",
      position: "Contributor",
      url: "https://github.com/godotengine/godot/pulls/hbina",
      summary: "Multi-platform 2D and 3D game engine written in C/C++14",
      highlights: (
        "Debugged various memory issues and crashes",
        "Implemented and fixed various UI features"
      )
    ),
    (
      organization: "Rust Coreutils",
      position: "Contributor",
      url: "https://github.com/uutils/coreutils/pulls/hbina",
      summary: "Cross-platform Rust rewrite of the GNU coreutils",
      highlights: (
        "Reimplemented tr to be fully compatible with GNU tr (passes all tests)",
        "Various improvement to ls",
        "Various improvement to more"
      )
    ),
    (
      organization: "redis",
      position: "Contributor",
      url: "https://github.com/redis/redis/pulls/hbina",
      summary: "Redis is an in-memory database that persists on disk. The data model is key-value, but many different kind of values are supported: Strings, Lists, Sets, Sorted Sets, Hashes, Streams, HyperLogLogs, Bitmaps.",
      highlights: (
        "Discovered and help fix a crash involving ZINTER of SET and ZSET",
        "Removed redundant checks when using small integers (slight performance improvement)",
        "Some fixes to usage of C string formatter",
        "Suggested a change to the implementation of sds to be more space efficient at the cost of some complexity (rejected)"
      )
    ),
    (
      organization: "Lapce",
      position: "Contributor",
      url: "https://github.com/lapce/lapce",
      summary: "Open source. Quick from launch to every keystroke, and batteries included. Compatible alternative to Microsoft's VSCode",
      highlights: (
        "Implement some UI features like collapsing panels and search panel preview",
        "Fixed some memory leaks with scratch documents",
        "Show unique paths to disambiguate multiple files with the same name",
        "Fix bad initialization of mouse pointers in the about modal"
      )
    )
  ),
  education: (
    (
      institution: "University of Ottawa",
      url: "https://www2.uottawa.ca/en",
      area: "Computer Engineering",
      studyType: "BSc",
      startDate: "2015-08",
      endDate: "2020-08",
      score: "7",
      courses: ()
    ),
  ),
  projects: (
    (
      name: "MIPS processor in VHDL",
      summary: "Circuit schematic for a basic MIPS processor that supports forwarding unit and branch protection in VHDL",
      highlights: ("Support forwarding unit", "Support branch protection"),
      keywords: ("VHDL", "Altera Quartus II Simulator"),
      url: "https://github.com/hbina/mips_processor",
      type: "circuit_schematic"
    ),
    (
      name: "radish",
      summary: "Multithreaded implementation of redis in Golang for learning purposes",
      highlights: (
        "Close to 90% of reference redis performance without any optimizations",
        "Discovered a crash in redis while developing this",
        "Passed unit/types/string, unit/types/zset, unit/types/set",
        "Supports block and non-blocking commands"
      ),
      keywords: ("redis", "golang"),
      url: "https://github.com/hbina/radish",
      type: "application"
    ),
    (
      name: "Fatuous",
      summary: "Basic 3D renderer",
      highlights: (
        "Able to load simple 3D models and skyboxes (Uses ASSIMP)",
        "Support object culling, tesselation and shadows"
      ),
      keywords: ("C++", "OpenGL"),
      url: "https://github.com/hbina/fatuous",
      type: "application"
    )
  )
)

// Color scheme
#let accent_color = rgb("#2C3E50")
#let link_color = rgb("#3498DB")

// Helper function to format dates
#let format_date(date_str) = {
  if date_str == none or date_str == "" {
    return "Present"
  }
  let parts = date_str.split("-")
  if parts.len() >= 2 {
    let year = parts.at(0)
    let month = parts.at(1)
    let months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    let month_idx = int(month) - 1
    if month_idx >= 0 and month_idx < 12 {
      return months.at(month_idx) + " " + year
    }
  }
  return date_str
}

// Set document metadata
#set document(
  title: resume_data.basics.name + " - Resume",
  author: resume_data.basics.name,
)

// Page setup
#set page(
  paper: "a4",
  margin: (x: 0.75in, y: 0.75in),
)

// Font settings
#set text(
  font: "Linux Libertine",
  size: 10pt,
  lang: "en",
)

// Heading styles
#show heading.where(level: 1): it => [
  #set text(size: 24pt, weight: "bold", fill: accent_color)
  #it.body
  #v(0.3em)
]

#show heading.where(level: 2): it => [
  #v(0.5em)
  #set text(size: 14pt, weight: "bold", fill: accent_color)
  #upper(it.body)
  #v(-0.3em)
  #line(length: 100%, stroke: 1pt + accent_color)
  #v(0.3em)
]

// Link styling
#show link: set text(fill: link_color)

// Name and contact header
#align(center)[
  #text(size: 28pt, weight: "bold", fill: accent_color)[
    #resume_data.basics.name
  ]

  #v(0.2em)

  #text(size: 12pt, fill: gray)[
    #resume_data.basics.label
  ]

  #v(0.3em)

  #text(size: 9pt)[
    #resume_data.basics.email |
    #resume_data.basics.phone |
    #link(resume_data.basics.url)[#resume_data.basics.url]
  ]

  #v(0.2em)

  #text(size: 9pt)[
    #{
      let profiles = resume_data.basics.profiles
      for (i, profile) in profiles.enumerate() [
        #link(profile.url)[#profile.network]#{
          if i < profiles.len() - 1 [ | ]
        }
      ]
    }
  ]
]

#v(0.5em)

// Summary
#if resume_data.basics.summary != none and resume_data.basics.summary != "" [
  == Summary
  #resume_data.basics.summary
]

// Work Experience
#if resume_data.work.len() > 0 [
  == Work Experience

  #{
    for job in resume_data.work [
      #text(weight: "bold", size: 11pt)[#job.position] #h(1fr) #text(style: "italic")[
        #format_date(job.startDate) -- #format_date(job.endDate)
      ]

      #v(-0.3em)

      #text(weight: "bold")[#job.name] | #text(style: "italic")[#job.location] | #link(job.url)[#job.url]

      #v(0.2em)

      #job.summary

      #if job.highlights.len() > 0 [
        #v(0.2em)
        #for highlight in job.highlights [
          - #highlight
        ]
      ]

      #v(0.5em)
    ]
  }
]

// Education
#if resume_data.education.len() > 0 [
  == Education

  #{
    for edu in resume_data.education [
      #text(weight: "bold", size: 11pt)[#edu.studyType in #edu.area] #h(1fr) #text(style: "italic")[
        #format_date(edu.startDate) -- #format_date(edu.endDate)
      ]

      #v(-0.3em)

      #text(weight: "bold")[#edu.institution] | #link(edu.url)[#edu.url]

      #v(0.5em)
    ]
  }
]

// Projects
#if resume_data.projects.len() > 0 [
  == Projects

  #{
    for project in resume_data.projects [
      #text(weight: "bold", size: 11pt)[#project.name] | #link(project.url)[#project.url]

      #v(0.2em)

      #project.summary

      #if project.highlights.len() > 0 [
        #v(0.2em)
        #for highlight in project.highlights [
          - #highlight
        ]
      ]

      #if project.keywords.len() > 0 [
        #v(0.2em)
        #text(style: "italic", size: 9pt, fill: gray)[
          Technologies: #project.keywords.join(", ")
        ]
      ]

      #v(0.5em)
    ]
  }
]

// Volunteer Work / Open Source Contributions
#if resume_data.volunteer.len() > 0 [
  == Open Source Contributions

  #{
    for vol in resume_data.volunteer [
      #text(weight: "bold", size: 11pt)[#vol.organization] -- #text(style: "italic")[#vol.position] | #link(vol.url)[View Contributions]

      #v(0.2em)

      #vol.summary

      #if vol.highlights.len() > 0 [
        #v(0.2em)
        #for highlight in vol.highlights [
          - #highlight
        ]
      ]

      #v(0.5em)
    ]
  }
]
