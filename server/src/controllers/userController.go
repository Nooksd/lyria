package controllers

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	database "server/src/db"
	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"golang.org/x/crypto/bcrypt"
)

var userCollection *mongo.Collection = database.OpenCollection(database.Client, "users")
var validate = validator.New()

func HashPassword(password string) string {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	if err != nil {
		log.Panic(err)
		return ""
	}
	return string(hashedPassword)
}

func CreateUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		var ctx, cancel = context.WithTimeout(context.Background(), 100*time.Second)
		defer cancel()

		var user model.User

		if err := c.BindJSON(&user); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "erro ao ler dados"})
			return
		}

		count, err := userCollection.CountDocuments(ctx, bson.M{"email": user.Email})
		if err != nil {
			log.Panic(err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "usuário já existe"})
			return
		}

		password := HashPassword(user.Password)
		user.Password = password
		user.AvatarUrl = "/avatar/" + user.Uid
		user.ID = primitive.NewObjectID()
		user.Uid = user.ID.Hex()
		user.CreatedAt = time.Now()
		user.UpdatedAt = user.CreatedAt

		validationErrors := validate.Struct(user)
		if validationErrors != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErrors.Error()})
			return
		}

		resultInsertionNumber, insertErr := userCollection.InsertOne(ctx, user)
		if insertErr != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "usuário não cadastrado"})
			return
		}
		defer cancel()

		c.JSON(http.StatusCreated, resultInsertionNumber)

	}
}

func UpdateOneUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		targetUserId := c.Param("userId")

		if ok, _, _ := helper.CheckAdminOrUidPermission(c, targetUserId); !ok {
			return
		}

		var ctx, cancel = context.WithTimeout(context.Background(), 100*time.Second)
		defer cancel()

		var userUpdates bson.M

		if err := c.BindJSON(&userUpdates); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Erro ao ler os dados de atualização"})
			return
		}

		delete(userUpdates, "userType")
		delete(userUpdates, "password")
		delete(userUpdates, "uid")

		filter := bson.M{"uid": targetUserId}
		update := bson.M{"$set": userUpdates}

		result, err := userCollection.UpdateOne(ctx, filter, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar os dados do usuário"})
			return
		}

		if result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		var userProfile model.User
		err = userCollection.FindOne(ctx, filter).Decode(&userProfile)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar o usuário atualizado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message": "Usuário atualizado com sucesso",
			"result":  result,
			"user":    userProfile,
		})
	}
}

func SearchUsers() gin.HandlerFunc {
	return func(c *gin.Context) {
		name := c.DefaultQuery("name", "")

		var ctx, cancel = context.WithTimeout(context.Background(), 100*time.Second)
		defer cancel()

		var users []model.User

		cursor, err := userCollection.Find(ctx, bson.M{"name": bson.M{"$regex": primitive.Regex{Pattern: ".*" + name + ".*", Options: "i"}}})
		if err != nil {
			log.Println("Erro ao buscar usuários:", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar usuários"})
			return
		}
		defer cursor.Close(ctx)

		for cursor.Next(ctx) {
			var user model.User
			if err := cursor.Decode(&user); err != nil {
				log.Println("Erro ao decodificar usuário:", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar usuários"})
				return
			}
			user.Password = ""
			user.Email = ""
			user.AvatarUrl = os.Getenv("SERVER_URL") + user.AvatarUrl
			users = append(users, user)
		}

		if err := cursor.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar usuários"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"users": users})
	}
}

func GetOneUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.Param("userId")

		var ctx, cancel = context.WithTimeout(context.Background(), 100+time.Second)

		var user model.User
		err := userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user)
		defer cancel()

		user.Password = ""
		user.Email = ""
		user.AvatarUrl = os.Getenv("SERVER_URL") + user.AvatarUrl

		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "usuário não encontrado", "erro": err.Error()})
			return
		}

		c.JSON(http.StatusOK, user)
	}

}
