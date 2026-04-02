// Resume data embedded directly in Typst
#let resume_data = (
  basics: (
    name: "Hanif Bin Ariffin",
    label: "Systems Engineer",
    email: "hanif.ariffin.4326@gmail.com",
    phone: "+60 175930487",
    url: "https://hbina.github.io",
    summary: "Systems Engineer specialized in high-performance computing and low-latency infrastructure. Proven track record in optimizing C++ applications at nanosecond scales, processing terabytes of market data, and contributing to core open-source infrastructure like Redis and Rust Coreutils.",
    location: (
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
  skills: (
    (
      category: "Languages",
      items: ("C++", "Rust", "C", "Go", "Python", "TypeScript", "VHDL")
    ),
    (
      category: "Systems & Low Latency",
      items: ("Kernel Bypass (ef_vi)", "SolarFlare", "Lock-free structures", "Shared Memory", "HFT Infrastructure")
    ),
    (
      category: "Data & Infrastructure",
      items: ("Redis Internals", "Market Data", "Big Data (TB scale)", "Linux/Unix", "Docker")
    )
  ),
  work: (
    (
      name: "Confinex Technologies",
      location: "Pulau Pinang",
      position: "Software Developer",
      url: "https://confinex.com/",
      startDate: "2023-12-31",
      endDate: "",
      summary: "Developing and maintaining an entire trading infrastructure stack for high-frequency trading.",
      highlights: (
        "Optimized C++ lock-free shared memory queue library for sub-microsecond IPC.",
        "Developed market data processing library with <400ns latency at P99.",
        "Built kernel bypass C++ applications using SolarFlare's ef_vi for direct NIC access.",
        "Engineered high-performance C++ bridges for Python JIT interaction with brokers.",
        "Automated processing of terabytes of market data across multiple global exchanges.",
      )
    ),
    (
      name: "Globelise",
      location: "Singapore",
      position: "Senior Fullstack Developer",
      url: "https://www.globelise.com/",
      startDate: "2022-02-01",
      endDate: "2022-07-01",
      summary: "Designed and implemented the backend for a global hiring management system.",
      highlights: (
        "Led development of 3rd party payroll integrations for international markets.",
        "Implemented secure, scalable backend architecture for multi-region deployment.",
      )
    ),
    (
      name: "Setel (Petronas)",
      location: "Malaysia",
      position: "Fullstack developer",
      url: "https://www.setel.com/",
      startDate: "2020-12-01",
      endDate: "2022-02-01",
      summary: "Maintained the loyalty and inventory systems for Malaysia's leading e-wallet.",
      highlights: (
        "Scaled the store ordering system to handle nationwide self-checkout volume.",
        "Optimized inventory tracking logic to ensure real-time consistency.",
      )
    )
  ),
  contributions: (
    (
      name: "Redis",
      role: "Contributor",
      summary: "Memory database used by millions of applications.",
      highlights: (
        "Fixed critical crash in ZINTER involving SET and ZSET types.",
        "Optimized integer checks and suggested SDS memory layout improvements.",
      )
    ),
    (
      name: "Rust Coreutils",
      role: "Contributor",
      summary: "GNU coreutils rewrite in Rust.",
      highlights: (
        "Fully reimplemented 'tr' utility to match POSIX/GNU standards (100% test pass).",
        "Performance and stability improvements to 'ls' and 'more'.",
      )
    ),
    (
      name: "Godot Engine",
      role: "Contributor",
      summary: "Open-source C++ game engine.",
      highlights: (
        "Resolved memory leaks and UI-related crashes in the core engine.",
      )
    )
  ),
  projects: (
    (
      name: "radish",
      summary: "High-performance Redis clone in Go.",
      highlights: ("90% of reference Redis performance using multithreaded architecture.",)
    ),
    (
      name: "MIPS Processor",
      summary: "VHDL circuit with forwarding unit and branch protection.",
      highlights: ("Implemented full instruction pipeline with hazard mitigation.",)
    )
  ),
  education: (
    (
      institution: "University of Ottawa",
      location: "Canada",
      area: "Computer Engineering",
      studyType: "BSc",
      startDate: "2015-08",
      endDate: "2020-08",
    ),
  ),
)

// Color scheme
#let accent_color = rgb("#1A237E") // Deep Blue
#let link_color = rgb("#1565C0")
#let light_gray = rgb("#F5F5F5")

// Helper function to format dates
#let format_date(date_str) = {
  if date_str == none or date_str == "" { return "Present" }
  let parts = date_str.split("-")
  if parts.len() >= 2 {
    let months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    let month_idx = int(parts.at(1)) - 1
    if month_idx >= 0 and month_idx < 12 {
      return months.at(month_idx) + " " + parts.at(0)
    }
  }
  return date_str
}

// Set document metadata
#set document(title: resume_data.basics.name + " - Resume", author: resume_data.basics.name)

// Page setup
#set page(paper: "a4", margin: (x: 0.5in, y: 0.5in))

// Font settings
#set text(font: "Libertinus Serif", size: 9.5pt) // Standard Typst-bundled font

// Heading styles
#show heading.where(level: 2): it => [
  #v(0.5em)
  #set text(size: 11pt, weight: "bold", fill: accent_color)
  #upper(it.body)
  #v(-0.6em)
  #line(length: 100%, stroke: 0.5pt + accent_color)
  #v(0.4em)
]

// Skill tag helper
#let skill_tag(content) = box(
  fill: light_gray,
  radius: 2pt,
  inset: (x: 4pt, y: 2pt),
  outset: (y: 1pt),
  text(size: 8pt, weight: "medium", content)
)

// Main layout
#grid(
  columns: (1fr, 2.5fr),
  column-gutter: 0.4in,
  
  // Sidebar (Left Column)
  [
    #align(center)[
      #box(
        width: 80%,
        stroke: 1pt + accent_color,
        radius: 12pt,
        clip: true,
        image("profile pic.jpg", width: 100%)
      )
    ]
    #v(1em)
    #text(size: 20pt, weight: "bold", fill: accent_color)[#resume_data.basics.name]
    #v(0.1em)
    #text(size: 12pt, weight: "medium", gray)[#resume_data.basics.label]
    
    #v(1em)
    
    // Contact Info
    #set text(size: 8.5pt)
    #link("mailto:" + resume_data.basics.email)[#resume_data.basics.email] \
    #resume_data.basics.phone \
    #link(resume_data.basics.url)[#resume_data.basics.url] \
    
    #v(0.8em)
    #{
      for profile in resume_data.basics.profiles [
        #link(profile.url)[#profile.network] \
      ]
    }
    
    #v(1.5em)
    
    == Technical Skills
    #{
      for skill_group in resume_data.skills [
        #text(weight: "bold", size: 9pt)[#skill_group.category] \
        #v(0.2em)
        #{
          for item in skill_group.items {
            skill_tag(item)
            h(3pt)
          }
        }
        #v(1em)
      ]
    }
    
    #v(1em)
    
    == Education
    #{
      for edu in resume_data.education [
        #text(weight: "bold")[#edu.studyType in #edu.area] \
        #edu.institution \
        #text(style: "italic", size: 8.5pt, gray)[
          #format_date(edu.startDate) -- #format_date(edu.endDate) \
          #edu.location
        ]
        #v(1em)
      ]
    }
  ],
  
  // Main Content (Right Column)
  [
    #v(0.5em)
    #resume_data.basics.summary
    
    #v(1.2em)
    
    == Work Experience
    #{
      for job in resume_data.work [
        #text(weight: "bold", size: 10.5pt)[#job.position] #h(1fr) #text(style: "italic", size: 9pt)[
          #format_date(job.startDate) -- #format_date(job.endDate)
        ] \
        #text(weight: "semibold")[#job.name] | #text(style: "italic")[#job.location]
        
        #v(0.2em)
        #text(size: 9pt)[#job.summary]
        #v(0.1em)
        #for highlight in job.highlights [
          - #highlight
        ]
        #v(0.8em)
      ]
    }
    
    == Open Source & Contributions
    #{
      for contrib in resume_data.contributions [
        #text(weight: "bold")[#contrib.name] -- #text(style: "italic")[#contrib.role]
        #v(0.2em)
        #for highlight in contrib.highlights [
          - #highlight
        ]
        #v(0.6em)
      ]
    }
    
    == Key Projects
    #{
      for project in resume_data.projects [
        #text(weight: "bold")[#project.name] | #text(size: 9pt, project.summary)
        #v(0.1em)
        #for highlight in project.highlights [
          - #highlight
        ]
        #v(0.6em)
      ]
    }
  ]
)
