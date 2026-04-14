package controllers

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"time"

	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func generateVerificationCode() string {
	code := ""
	for i := 0; i < 6; i++ {
		n, _ := rand.Int(rand.Reader, big.NewInt(10))
		code += fmt.Sprintf("%d", n.Int64())
	}
	return code
}

func RegisterUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		var registerData struct {
			Name     string `json:"name" binding:"required"`
			Email    string `json:"email" binding:"required"`
			Password string `json:"password" binding:"required"`
		}

		if err := c.ShouldBindJSON(&registerData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Todos os campos são obrigatórios"})
			return
		}

		if len(registerData.Password) < 6 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "A senha deve ter pelo menos 6 caracteres"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		count, err := userCollection.CountDocuments(ctx, bson.M{"email": registerData.Email})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro interno"})
			return
		}

		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "Este email já está cadastrado"})
			return
		}

		verificationCode := generateVerificationCode()

		user := model.User{
			ID:                 primitive.NewObjectID(),
			Name:               registerData.Name,
			Email:              registerData.Email,
			Password:           HashPassword(registerData.Password),
			UserType:           "USER",
			Favorites:          []primitive.ObjectID{},
			EmailVerified:      false,
			VerificationCode:   verificationCode,
			VerificationExpiry: time.Now().Add(24 * time.Hour),
			CreatedAt:          time.Now(),
			UpdatedAt:          time.Now(),
		}
		user.Uid = user.ID.Hex()
		user.AvatarUrl = "/image/avatar/" + user.Uid

		validationErrors := validate.Struct(user)
		if validationErrors != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErrors.Error()})
			return
		}

		_, err = userCollection.InsertOne(ctx, user)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar usuário"})
			return
		}

		serverURL := os.Getenv("SERVER_URL")
		verificationLink := fmt.Sprintf("%s/auth/verify-email?code=%s&email=%s", serverURL, verificationCode, registerData.Email)

		emailData := helper.EmailData{
			Name:             registerData.Name,
			VerificationLink: verificationLink,
			Code:             verificationCode,
		}

		go func() {
			if err := helper.SendVerificationEmail(registerData.Email, emailData); err != nil {
				fmt.Printf("Erro ao enviar email de verificação: %v\n", err)
			}
		}()

		c.JSON(http.StatusCreated, gin.H{
			"message": "Conta criada com sucesso! Verifique seu email.",
		})
	}
}

func VerifyEmail() gin.HandlerFunc {
	return func(c *gin.Context) {
		var verifyData struct {
			Email string `json:"email" binding:"required"`
			Code  string `json:"code" binding:"required"`
		}

		if err := c.ShouldBindJSON(&verifyData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email e código são obrigatórios"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user model.User
		err := userCollection.FindOne(ctx, bson.M{"email": verifyData.Email}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		if user.EmailVerified {
			c.JSON(http.StatusOK, gin.H{"message": "Email já verificado"})
			return
		}

		if user.VerificationCode != verifyData.Code {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Código de verificação inválido"})
			return
		}

		if time.Now().After(user.VerificationExpiry) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Código de verificação expirado"})
			return
		}

		_, err = userCollection.UpdateOne(ctx,
			bson.M{"email": verifyData.Email},
			bson.M{
				"$set": bson.M{
					"emailVerified": true,
					"updatedAt":     time.Now(),
				},
				"$unset": bson.M{
					"verificationCode":   "",
					"verificationExpiry": "",
				},
			},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao verificar email"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Email verificado com sucesso!"})
	}
}

func ResendVerification() gin.HandlerFunc {
	return func(c *gin.Context) {
		var data struct {
			Email string `json:"email" binding:"required"`
		}

		if err := c.ShouldBindJSON(&data); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email é obrigatório"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user model.User
		err := userCollection.FindOne(ctx, bson.M{"email": data.Email}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		if user.EmailVerified {
			c.JSON(http.StatusOK, gin.H{"message": "Email já verificado"})
			return
		}

		verificationCode := generateVerificationCode()

		_, err = userCollection.UpdateOne(ctx,
			bson.M{"email": data.Email},
			bson.M{"$set": bson.M{
				"verificationCode":   verificationCode,
				"verificationExpiry": time.Now().Add(24 * time.Hour),
				"updatedAt":          time.Now(),
			}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao reenviar verificação"})
			return
		}

		serverURL := os.Getenv("SERVER_URL")
		verificationLink := fmt.Sprintf("%s/auth/verify-email?code=%s&email=%s", serverURL, verificationCode, data.Email)

		emailData := helper.EmailData{
			Name:             user.Name,
			VerificationLink: verificationLink,
			Code:             verificationCode,
		}

		go func() {
			if err := helper.SendVerificationEmail(data.Email, emailData); err != nil {
				fmt.Printf("Erro ao reenviar email: %v\n", err)
			}
		}()

		c.JSON(http.StatusOK, gin.H{"message": "Email de verificação reenviado"})
	}
}
