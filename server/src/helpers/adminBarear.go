package helpers

import (
	// "net/http"

	"github.com/gin-gonic/gin"
	// "github.com/golang-jwt/jwt/v5"
)

func CheckAdminOrUidPermission(c *gin.Context, targetUid string) (bool, string, string) {
	// userClaims, exists := c.Get("user")
	// if !exists {
	// 	c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
	// 	return false, "", ""
	// }

	// claims, ok := userClaims.(jwt.MapClaims)
	// if !ok {
	// 	c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
	// 	return false, "", ""
	// }

	// userType := claims["UserType"].(string)
	// userId := claims["Uid"].(string)

	// if userType != "ADMIN" && userId != targetUid {
	// 	c.JSON(http.StatusUnauthorized, gin.H{"error": "Você não tem permissão para acessar este recurso"})
	// 	return false, userType, userId
	// }

	// return true, userType, userId
	return true, "", ""
}
