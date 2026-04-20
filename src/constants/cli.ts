export const HELP_TEXT = `sqlboot

Installs Oracle SQL*Plus, Docker Oracle XE, rlwrap, and the universal sqlboot command.

Available options:
  init                      Initialize sqlboot setup
  help                      Show this help
  start                     Launch SQL*Plus
  status                    Show current sqlboot status
  logs                      Show recent Oracle container logs
  doctor                    Run environment checks
  stop                      Stop Oracle container
  uninstall                 Remove sqlboot-managed resources
  reset-pwd <new-password>  Reset Oracle password

Environment overrides:
  SQLBOOT_ORACLE_PASSWORD
  SQLBOOT_ORACLE_IMAGE
  SQLBOOT_ORACLE_CONTAINER
  SQLBOOT_ORACLE_PORT
  SQLBOOT_ORACLE_SERVICE
  SQLBOOT_IC_BASIC_URL
  SQLBOOT_IC_SQLPLUS_URL
`;
