indexing

	description: "Constants describing defined tag file formats."
	revision: "$Revision: 189 $"
	date: "$Date: 2002-08-26 04:16:52 +0100 (Mon, 26 Aug 2002) $"
	copyright: "Copyright 2002 Darren Hiebert and others"
	license: "Eiffel Forum License, version 1"

class TAG_FILE_FORMATS

feature -- Access

	Format_original: INTEGER is 1
			-- Original tag file format

	Format_extended: INTEGER is 2
			-- Extended tag file format

feature -- Status report

	valid_format (format: INTEGER): BOOLEAN is
			-- Is `format' a valid tag file format?
		do
			Result := format = Format_original or format = Format_extended
		ensure
			definition: Result implies
				(format = Format_original or format = Format_extended)
		end

end
