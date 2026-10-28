package com.example;

import org.springframework.context.support.ClassPathXmlApplicationContext;

public final class Main {
    private Main() {}

    public static void main(String[] args) {
        try (ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("spring.xml")) {
            System.out.println("SPRING_CONTEXT_LOADED");
        }
    }
}
