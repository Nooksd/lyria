package helpers

import (
	"bytes"
	"fmt"
	"html/template"
	"net/smtp"
	"os"
)

type EmailData struct {
	Name             string
	VerificationLink string
	Code             string
}

const verificationTemplate = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body { margin: 0; padding: 0; background-color: #171717; font-family: Arial, sans-serif; }
  .container { max-width: 600px; margin: 0 auto; background-color: #1e1e1e; border-radius: 16px; overflow: hidden; }
  .header { background: linear-gradient(135deg, #6366f1, #8b5cf6); padding: 40px 30px; text-align: center; }
  .header h1 { color: #fff; margin: 0; font-size: 28px; letter-spacing: 2px; }
  .header p { color: rgba(255,255,255,0.8); margin: 10px 0 0; font-size: 14px; }
  .body { padding: 40px 30px; }
  .body p { color: #a0a0a0; font-size: 16px; line-height: 1.6; }
  .body .name { color: #fff; font-weight: bold; }
  .code-box { background-color: #2a2a2a; border: 2px solid #6366f1; border-radius: 12px; padding: 20px; text-align: center; margin: 30px 0; }
  .code-box .code { color: #6366f1; font-size: 36px; font-weight: bold; letter-spacing: 8px; }
  .code-box .label { color: #666; font-size: 12px; margin-top: 8px; }
  .btn { display: inline-block; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: #fff; text-decoration: none; padding: 14px 40px; border-radius: 30px; font-size: 16px; font-weight: bold; margin: 20px 0; }
  .footer { padding: 20px 30px; text-align: center; border-top: 1px solid #2a2a2a; }
  .footer p { color: #555; font-size: 12px; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>LYRIA</h1>
    <p>Verificação de Email</p>
  </div>
  <div class="body">
    <p>Olá <span class="name">{{.Name}}</span>,</p>
    <p>Bem-vindo ao Lyria! Para completar seu cadastro, use o código abaixo para verificar seu email:</p>
    <div class="code-box">
      <div class="code">{{.Code}}</div>
      <div class="label">CÓDIGO DE VERIFICAÇÃO</div>
    </div>
    <p>Ou clique no botão abaixo:</p>
    <center><a href="{{.VerificationLink}}" class="btn">Verificar Email</a></center>
    <p style="color:#555; font-size:13px; margin-top:30px;">Se você não criou uma conta no Lyria, ignore este email.</p>
  </div>
  <div class="footer">
    <p>© 2026 Lyria. Todos os direitos reservados.</p>
  </div>
</div>
</body>
</html>`

func SendVerificationEmail(toEmail string, data EmailData) error {
	smtpHost := os.Getenv("SMTP_HOST")
	smtpPort := os.Getenv("SMTP_PORT")
	smtpUser := os.Getenv("SMTP_USER")
	smtpPass := os.Getenv("SMTP_PASS")
	smtpFrom := os.Getenv("SMTP_FROM")

	if smtpHost == "" || smtpPort == "" || smtpUser == "" || smtpPass == "" {
		return fmt.Errorf("configuração SMTP incompleta")
	}

	if smtpFrom == "" {
		smtpFrom = smtpUser
	}

	tmpl, err := template.New("verification").Parse(verificationTemplate)
	if err != nil {
		return fmt.Errorf("erro ao parsear template: %v", err)
	}

	var body bytes.Buffer
	if err := tmpl.Execute(&body, data); err != nil {
		return fmt.Errorf("erro ao executar template: %v", err)
	}

	mime := "MIME-version: 1.0;\nContent-Type: text/html; charset=\"UTF-8\";\n\n"
	subject := "Subject: Lyria - Verificação de Email\n"
	from := fmt.Sprintf("From: Lyria <%s>\n", smtpFrom)
	to := fmt.Sprintf("To: %s\n", toEmail)

	msg := []byte(from + to + subject + mime + body.String())

	auth := smtp.PlainAuth("", smtpUser, smtpPass, smtpHost)
	addr := smtpHost + ":" + smtpPort

	err = smtp.SendMail(addr, auth, smtpFrom, []string{toEmail}, msg)
	if err != nil {
		return fmt.Errorf("erro ao enviar email: %v", err)
	}

	return nil
}
