from pathlib import Path
p=Path('helpers/auth_x11.c')
s=p.read_text()
anchor='void DisplayMessage(const char *title, const char *str, int is_warning) {'
assert s.count(anchor)==1
s=s.replace(anchor,'#include "criket_lock_card.c"\n\n'+anchor+'\n  if (GetIntSetting("CRIKET_LOCK_STYLE", 0)) {\n    CriketDisplayMessage(title, str, is_warning);\n    return;\n  }')
anchor='    DisplayMessage(msg, priv.displaybuf, 0);'
assert s.count(anchor)==1
s=s.replace(anchor,'    criket_input_prompt = 1;\n    criket_input_secret = !echo;\n'+anchor+'\n    criket_input_prompt = criket_input_secret = 0;')
p.write_text(s)
# Add an existing protocol error message; preserve every PAM result and retry.
p=Path('helpers/authproto_pam.c')
s=p.read_text()
anchor='    switch (status) {'
assert s.count(anchor)==1
s=s.replace(anchor,'''
    if (pam_call == pam_authenticate && status == PAM_AUTH_ERR &&
        GetIntSetting("CRIKET_LOCK_STYLE", 0)) {
      WritePacket(1, PTYPE_ERROR_MESSAGE, "Пароль не принят");
    }
'''+anchor)
p.write_text(s)
