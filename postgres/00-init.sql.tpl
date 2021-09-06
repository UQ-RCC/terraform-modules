%{ for user, opts in users ~}
------- ${user} -------
CREATE ROLE ${user};
%{ for opt in opts.options ~}
ALTER ROLE ${user} ${opt};
%{ endfor ~}
%{ if opts.password != "" ~}
ALTER ROLE ${user} ENCRYPTED PASSWORD '${opts.password}';
%{ endif ~}
%{ endfor }

%{ for db, opts in databases ~}
------- ${db} -------
CREATE DATABASE ${db} OWNER ${opts.owner};
%{ endfor }
